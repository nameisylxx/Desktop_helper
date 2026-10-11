import SwiftUI

struct RemindersCard: View {
    @Environment(EventKitService.self) private var eventKit
    @State private var newTitle = ""
    @State private var newDue: QuickDue = .none

    var body: some View {
        Card("Plans & To-Dos", systemImage: "checklist") {
            switch eventKit.reminderAccess {
            case .granted:
                groups
                addField
                if let error = eventKit.lastError {
                    Text(error).font(Theme.Fonts.caption).foregroundStyle(.red)
                        .padding(.leading, Theme.Layout.textInset)
                }
            case .notDetermined:
                AccessPrompt(message: "Reminders access is needed to show to-dos", buttonTitle: "Allow Reminders Access") {
                    Task {
                        await eventKit.requestAccessIfNeeded()
                        await eventKit.refresh()
                    }
                }
            case .denied:
                AccessPrompt(message: "Reminders access is turned off", buttonTitle: "Open System Settings") {
                    eventKit.openPrivacySettings(for: .reminder)
                }
            }
        }
    }

    @ViewBuilder
    private var groups: some View {
        let sections = ReminderSection.group(eventKit.reminders)
        if sections.isEmpty {
            EmptyNote("No open to-dos")
        }
        ForEach(sections) { section in
            VStack(alignment: .leading, spacing: Theme.Layout.rowSpacing) {
                SectionLabel(section.title, color: section.id == .overdue ? .red : .secondary)
                ForEach(section.items) { item in
                    ReminderRow(item: item) { eventKit.complete(item) }
                }
            }
        }
    }

    /// 添加行和待办行用同一套列：加号在标记列，输入框在正文列
    private var addField: some View {
        MarkerRow {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.secondary)
        } content: {
            TextField("Add a to-do…", text: $newTitle)
                .textFieldStyle(.plain)
                .font(Theme.Fonts.body)
                .onSubmit(add)
        } trailing: {
            Picker("", selection: $newDue) {
                ForEach(QuickDue.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .menuStyle(.borderlessButton)
            .font(Theme.Fonts.detail)
            .fixedSize()
        }
        .padding(.top, 2)
    }

    private func add() {
        eventKit.addReminder(title: newTitle, due: newDue.date)
        newTitle = ""
        newDue = .none
    }
}

private struct ReminderRow: View {
    let item: ReminderItem
    let onComplete: () -> Void

    var body: some View {
        MarkerRow {
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(item.color)
            }
            .buttonStyle(.plain)
            .help("Mark as done")
        } content: {
            Text(item.title).font(Theme.Fonts.body).lineLimit(2)
        } trailing: {
            if let due = item.due {
                Text(DueFormatter.relative(due, hasTime: item.hasTime))
                    .font(Theme.Fonts.detail)
                    .foregroundStyle(DueFormatter.isOverdue(due, hasTime: item.hasTime) ? Color.red : Color.secondary)
            }
        }
    }
}

/// 待办分组：已逾期 / 今天 / 之后 / 无日期
private struct ReminderSection: Identifiable {
    enum Kind: Int, CaseIterable { case overdue, today, later, noDate }

    let id: Kind
    let items: [ReminderItem]

    var title: String {
        switch id {
        case .overdue: "Overdue"
        case .today: "Today"
        case .later: "Later"
        case .noDate: "No Date"
        }
    }

    static func group(_ reminders: [ReminderItem]) -> [ReminderSection] {
        let dict = Dictionary(grouping: reminders) { r -> Kind in
            guard let due = r.due else { return .noDate }
            if DueFormatter.isOverdue(due, hasTime: r.hasTime) { return .overdue }
            return DueFormatter.dayOffset(due) == 0 ? .today : .later
        }
        return Kind.allCases.compactMap { kind in
            dict[kind].map { ReminderSection(id: kind, items: $0) }
        }
    }
}

/// 快速添加时可选的 due 日期
enum QuickDue: String, CaseIterable, Identifiable {
    case none, today, tomorrow, nextWeek
    var id: Self { self }

    var label: String {
        switch self {
        case .none: "No Date"
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .nextWeek: "Next Week"
        }
    }

    var date: Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        switch self {
        case .none: return nil
        case .today: return today
        case .tomorrow: return cal.date(byAdding: .day, value: 1, to: today)
        case .nextWeek: return cal.date(byAdding: .day, value: 7, to: today)
        }
    }
}
