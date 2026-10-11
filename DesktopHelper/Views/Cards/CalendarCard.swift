import SwiftUI

struct CalendarCard: View {
    @Environment(EventKitService.self) private var eventKit
    @AppStorage(SettingsKey.calendarDays) private var days = 7

    var body: some View {
        Card("Calendar", systemImage: "calendar", accessory: Date.now.formatted(.dateTime.month(.wide).year().locale(AppLocale.locale))) {
            switch eventKit.eventAccess {
            case .granted:
                MiniMonthView(markedDays: eventKit.monthEventDays)
                Divider()
                eventList
            case .notDetermined:
                AccessPrompt(message: "Calendar access is needed to show events", buttonTitle: "Allow Calendar Access") {
                    Task {
                        await eventKit.requestAccessIfNeeded()
                        await eventKit.refresh()
                    }
                }
            case .denied:
                AccessPrompt(message: "Calendar access is turned off", buttonTitle: "Open System Settings") {
                    eventKit.openPrivacySettings(for: .event)
                }
            }
        }
    }

    @ViewBuilder
    private var eventList: some View {
        let groups = groupedByDay(eventKit.events)
        if groups.isEmpty {
            EmptyNote("No events in the next \(days) days")
        }
        ForEach(groups, id: \.day) { group in
            VStack(alignment: .leading, spacing: Theme.Layout.rowSpacing) {
                SectionLabel(dayTitle(group.day))
                ForEach(group.events) { event in
                    MarkerRow {
                        Circle().fill(event.color).frame(width: 7, height: 7)
                    } content: {
                        Text(event.title).font(Theme.Fonts.body).lineLimit(1)
                    } trailing: {
                        Text(event.isAllDay ? "All day" : event.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: AppLocale.locale)))
                            .font(Theme.Fonts.detail)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func groupedByDay(_ events: [CalendarEvent]) -> [(day: Date, events: [CalendarEvent])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // 跨天事件（从之前开始的）归到今天
        let dict = Dictionary(grouping: events) { cal.startOfDay(for: max($0.start, today)) }
        return dict.keys.sorted().map { ($0, dict[$0]!) }
    }

    private func dayTitle(_ day: Date) -> String {
        switch DueFormatter.dayOffset(day) {
        case 0: "Today"
        case 1: "Tomorrow"
        default: day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(AppLocale.locale))
        }
    }
}

/// 本月迷你月历，有日程的日子下面带小圆点
struct MiniMonthView: View {
    let markedDays: Set<Date>

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        let dayCount = cal.range(of: .day, in: .month, for: monthStart)!.count
        let leading = (cal.component(.weekday, from: monthStart) - cal.firstWeekday + 7) % 7
        let symbols = Self.weekdaySymbols(cal)
        let cells: [Date?] = Array(repeating: nil, count: leading)
            + (0..<dayCount).map { cal.date(byAdding: .day, value: $0, to: monthStart) }

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(symbols.indices, id: \.self) { i in
                Text(symbols[i])
                    .font(Theme.Fonts.sectionLabel)
                    .foregroundStyle(.secondary)
                    .frame(height: 16)
            }
            ForEach(cells.indices, id: \.self) { i in
                if let date = cells[i] {
                    dayCell(date, isToday: date == today)
                } else {
                    Color.clear.frame(height: 27)
                }
            }
        }
    }

    private func dayCell(_ date: Date, isToday: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(isToday ? Theme.font(12, .bold) : Theme.font(12, .medium))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .frame(width: 22, height: 22)
                .background(isToday ? Color.accentColor : .clear, in: Circle())
            Circle()
                .fill(markedDays.contains(date) && !isToday ? Color.accentColor : .clear)
                .frame(width: 3, height: 3)
        }
        .frame(height: 27)
    }

    /// 按系统的"每周第一天"排列的星期简称
    private static func weekdaySymbols(_ cal: Calendar) -> [String] {
        // 星期名用英文，但"每周第一天"仍然跟随系统设置
        var english = Calendar(identifier: .gregorian)
        english.locale = AppLocale.locale
        let symbols = english.veryShortStandaloneWeekdaySymbols
        let shift = cal.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
