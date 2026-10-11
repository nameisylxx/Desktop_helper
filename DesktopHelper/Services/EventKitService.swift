import AppKit
import EventKit
import SwiftUI

/// 读写 Apple 日历和提醒事项。在手机或系统 App 里改了，面板会自动刷新。
@MainActor
@Observable
final class EventKitService {
    enum Access { case notDetermined, granted, denied }

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private(set) var eventAccess: Access = .notDetermined
    private(set) var reminderAccess: Access = .notDetermined

    /// 今天起 N 天内的事件
    private(set) var events: [CalendarEvent] = []
    /// 本月有事件的日子（startOfDay），给迷你月历画小圆点
    private(set) var monthEventDays: Set<Date> = []
    /// 所有未完成的提醒
    private(set) var reminders: [ReminderItem] = []

    private(set) var eventCalendars: [CalendarSource] = []
    private(set) var reminderLists: [CalendarSource] = []
    private(set) var lastError: String?

    /// 在设置里取消勾选的日历 / 提醒列表
    var hiddenCalendarIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: SettingsKey.hiddenCalendarIDs) ?? []) {
        didSet {
            UserDefaults.standard.set(Array(hiddenCalendarIDs), forKey: SettingsKey.hiddenCalendarIDs)
            Task { await refresh() }
        }
    }

    /// 快速添加待办时放进哪个列表（nil = 系统默认列表）
    var defaultReminderListID: String? = UserDefaults.standard.string(forKey: SettingsKey.defaultReminderListID) {
        didSet { UserDefaults.standard.set(defaultReminderListID, forKey: SettingsKey.defaultReminderListID) }
    }

    init() {
        updateAccessStatus()
    }

    func start() async {
        observeChanges()
        await requestAccessIfNeeded()
        await refresh()
    }

    // MARK: - 权限

    func requestAccessIfNeeded() async {
        var asked = false
        if eventAccess == .notDetermined {
            _ = try? await store.requestFullAccessToEvents()
            asked = true
        }
        if reminderAccess == .notDetermined {
            _ = try? await store.requestFullAccessToReminders()
            asked = true
        }
        // 刚授权后重置一下，确保 store 能读到数据
        if asked { store.reset() }
        updateAccessStatus()
    }

    func openPrivacySettings(for type: EKEntityType) {
        let pane = type == .event ? "Privacy_Calendars" : "Privacy_Reminders"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func updateAccessStatus() {
        eventAccess = Self.access(for: .event)
        reminderAccess = Self.access(for: .reminder)
    }

    private static func access(for type: EKEntityType) -> Access {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    // MARK: - 读取

    func refresh() async {
        updateAccessStatus()
        refreshEvents()
        await refreshReminders()
    }

    private func refreshEvents() {
        guard eventAccess == .granted else {
            events = []
            monthEventDays = []
            eventCalendars = []
            return
        }
        let cal = Calendar.current
        let all = store.calendars(for: .event)
        eventCalendars = all.map(CalendarSource.init).sorted { ($0.sourceTitle, $0.title) < ($1.sourceTitle, $1.title) }
        let visible = all.filter { !hiddenCalendarIDs.contains($0.calendarIdentifier) }
        guard !visible.isEmpty else {
            events = []
            monthEventDays = []
            return
        }

        let today = cal.startOfDay(for: .now)
        let days = max(1, UserDefaults.standard.integer(forKey: SettingsKey.calendarDays))
        let end = cal.date(byAdding: .day, value: days, to: today)!
        let upcoming = store.predicateForEvents(withStart: today, end: end, calendars: visible)
        events = store.events(matching: upcoming).map(CalendarEvent.init).sorted { $0.start < $1.start }

        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!
        let month = store.predicateForEvents(withStart: monthStart, end: monthEnd, calendars: visible)
        var marked = Set<Date>()
        for event in store.events(matching: month) {
            var day = cal.startOfDay(for: max(event.startDate, monthStart))
            let last = min(event.endDate, monthEnd)
            repeat {
                marked.insert(day)
                day = cal.date(byAdding: .day, value: 1, to: day)!
            } while day < last
        }
        monthEventDays = marked
    }

    private func refreshReminders() async {
        guard reminderAccess == .granted else {
            reminders = []
            reminderLists = []
            return
        }
        let all = store.calendars(for: .reminder)
        reminderLists = all.map(CalendarSource.init).sorted { ($0.sourceTitle, $0.title) < ($1.sourceTitle, $1.title) }
        let visible = all.filter { !hiddenCalendarIDs.contains($0.calendarIdentifier) }
        guard !visible.isEmpty else {
            reminders = []
            return
        }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: visible)
        reminders = await Self.fetchReminders(store, predicate).sorted(by: ReminderItem.displayOrder)
    }

    /// fetchReminders 的回调在后台线程，所以放在 nonisolated 里转成值类型再回来
    nonisolated private static func fetchReminders(_ store: EKEventStore, _ predicate: NSPredicate) async -> [ReminderItem] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: (result ?? []).map(ReminderItem.init))
            }
        }
    }

    // MARK: - 写入

    func complete(_ item: ReminderItem) {
        guard let reminder = store.calendarItem(withIdentifier: item.id) as? EKReminder else { return }
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
            reminders.removeAll { $0.id == item.id }
            lastError = nil
        } catch {
            lastError = "Couldn't complete: \(error.localizedDescription)"
        }
    }

    /// 新建提醒。includesTime 为 false 时只设日期（和提醒事项 App 里"无时间"一致）
    func addReminder(title: String, due: Date? = nil, includesTime: Bool = false) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, reminderAccess == .granted else { return }

        let reminder = EKReminder(eventStore: store)
        reminder.title = trimmed
        reminder.calendar = defaultReminderListID.flatMap { store.calendar(withIdentifier: $0) }
            ?? store.defaultCalendarForNewReminders()
        if let due {
            let fields: Set<Calendar.Component> = includesTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
            reminder.dueDateComponents = Calendar.current.dateComponents(fields, from: due)
        }
        do {
            try store.save(reminder, commit: true)
            lastError = nil
        } catch {
            lastError = "Couldn't add: \(error.localizedDescription)"
        }
        Task { await refreshReminders() }
    }

    // MARK: - 监听

    private func observeChanges() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        let refresh: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        observers.append(center.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main, using: refresh))
        observers.append(center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main, using: refresh))
    }
}
