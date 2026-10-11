import Foundation

/// Due Soon 文件区里的一个文件。只存书签（bookmark），不复制原文件。
struct ShelfItem: Codable, Identifiable, Hashable {
    let id: UUID
    /// 文件书签：原文件被移动或改名后仍能找到
    var bookmark: Data
    var displayName: String
    var dueDate: Date?
    let addedAt: Date
}
