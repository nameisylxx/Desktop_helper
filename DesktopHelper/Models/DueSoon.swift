import Foundation

/// Due Soon 列表里的一项：来自提醒事项或文件区
struct DueSoonItem: Identifiable, Hashable {
    enum Kind: Hashable { case reminder, file }

    let id: String
    let sourceID: String
    let title: String
    let due: Date
    let hasTime: Bool
    let kind: Kind
}

enum DueSoon {
    /// 合并 N 天内（含已逾期）要 due 的提醒和文件，按时间排序
    static func items(reminders: [ReminderItem], files: [ShelfItem], withinDays days: Int, now: Date = .now) -> [DueSoonItem] {
        let cal = Calendar.current
        guard let limit = cal.date(byAdding: .day, value: days + 1, to: cal.startOfDay(for: now)) else { return [] }

        var result: [DueSoonItem] = []
        for r in reminders {
            guard let due = r.due, due < limit else { continue }
            result.append(DueSoonItem(id: "r-\(r.id)", sourceID: r.id, title: r.title, due: due, hasTime: r.hasTime, kind: .reminder))
        }
        for f in files {
            guard let due = f.dueDate, due < limit else { continue }
            result.append(DueSoonItem(id: "f-\(f.id)", sourceID: f.id.uuidString, title: f.displayName, due: due, hasTime: false, kind: .file))
        }
        return result.sorted { $0.due < $1.due }
    }
}

/// "Today / Tomorrow / In 3 days / 2 days overdue" 这类相对时间文字
enum DueFormatter {
    static func dayOffset(_ date: Date, from now: Date = .now) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 0
    }

    static func relative(_ date: Date, hasTime: Bool = false) -> String {
        let days = dayOffset(date)
        var text: String
        switch days {
        case ..<0: text = -days == 1 ? "1 day overdue" : "\(-days) days overdue"
        case 0: text = "Today"
        case 1: text = "Tomorrow"
        default: text = "In \(days) days"
        }
        if hasTime {
            text += " " + date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: AppLocale.locale))
        }
        return text
    }

    static func isOverdue(_ date: Date, hasTime: Bool) -> Bool {
        hasTime ? date < .now : dayOffset(date) < 0
    }

    /// 今天起第 n 天的 23:59
    static func endOfDay(daysFromToday n: Int) -> Date {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: n, to: cal.startOfDay(for: .now)) ?? .now
        return cal.date(bySettingHour: 23, minute: 59, second: 0, of: day) ?? day
    }
}
