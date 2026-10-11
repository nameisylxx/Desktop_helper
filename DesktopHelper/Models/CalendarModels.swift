import EventKit
import SwiftUI

/// 日历事件（从 EKEvent 拷贝出来的值类型，View 层不直接碰 EventKit）
struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarTitle: String
    let color: Color
    let location: String?

    init(_ event: EKEvent) {
        // 重复事件的 eventIdentifier 相同，加上开始时间区分
        id = "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)"
        title = event.title ?? "(No Title)"
        start = event.startDate
        end = event.endDate
        isAllDay = event.isAllDay
        calendarTitle = event.calendar?.title ?? ""
        color = event.calendar.map { Color(cgColor: $0.cgColor) } ?? .accentColor
        location = event.location
    }
}

/// 提醒事项里的一条（未完成）待办
struct ReminderItem: Identifiable, Hashable {
    let id: String
    let title: String
    let due: Date?
    /// 提醒是否设置了具体时间（否则只有日期）
    let hasTime: Bool
    let listTitle: String
    let color: Color
    let priority: Int
    let notes: String?

    init(_ reminder: EKReminder) {
        id = reminder.calendarItemIdentifier
        title = reminder.title ?? "(No Title)"
        let comps = reminder.dueDateComponents
        due = comps.flatMap { Calendar.current.date(from: $0) }
        hasTime = comps?.hour != nil
        listTitle = reminder.calendar?.title ?? ""
        color = reminder.calendar.map { Color(cgColor: $0.cgColor) } ?? .accentColor
        priority = reminder.priority
        notes = reminder.notes
    }

    /// 有日期的在前（按日期），没日期的在后；同日期按优先级、标题
    static func displayOrder(_ a: ReminderItem, _ b: ReminderItem) -> Bool {
        switch (a.due, b.due) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default:
            // EventKit 优先级：1 最高，9 最低，0 无
            let pa = a.priority == 0 ? 10 : a.priority
            let pb = b.priority == 0 ? 10 : b.priority
            return pa != pb ? pa < pb : a.title < b.title
        }
    }
}

/// 一个日历或一个提醒列表
struct CalendarSource: Identifiable, Hashable {
    let id: String
    let title: String
    let sourceTitle: String
    let color: Color

    init(_ calendar: EKCalendar) {
        id = calendar.calendarIdentifier
        title = calendar.title
        sourceTitle = calendar.source?.title ?? ""
        color = Color(cgColor: calendar.cgColor)
    }
}
