import SwiftUI

struct DueSoonCard: View {
    @Environment(EventKitService.self) private var eventKit
    @Environment(ShelfStore.self) private var shelf
    @AppStorage(SettingsKey.dueSoonDays) private var days = 7

    var body: some View {
        Card("Due Soon", systemImage: "hourglass") {
            let items = DueSoon.items(reminders: eventKit.reminders, files: shelf.items, withinDays: days)
            if items.isEmpty {
                EmptyNote("Nothing due in the next \(days) days")
            } else {
                VStack(alignment: .leading, spacing: Theme.Layout.rowSpacing) {
                    ForEach(items) { item in
                        MarkerRow {
                            Image(systemName: item.kind == .file ? "doc" : "checklist")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        } content: {
                            Text(item.title).font(Theme.Fonts.body).lineLimit(1)
                        } trailing: {
                            Text(DueFormatter.relative(item.due, hasTime: item.hasTime))
                                .font(Theme.Fonts.detail)
                                .foregroundStyle(DueFormatter.isOverdue(item.due, hasTime: item.hasTime) ? Color.red : Color.secondary)
                        }
                    }
                }
            }
            FileShelfView()
        }
    }
}
