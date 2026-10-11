import SwiftUI

/// 文件区：把文件拖进来，显示成桌面一样的图标网格
struct FileShelfView: View {
    @Environment(ShelfStore.self) private var shelf
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if shelf.items.isEmpty {
                Text("Drop PDFs or other files here")
                    .font(Theme.Fonts.detail)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 70)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 6)], alignment: .leading, spacing: 10) {
                    ForEach(shelf.sortedItems) { item in
                        FileIconView(item: item, url: shelf.url(for: item))
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.4))
        )
        .dropDestination(for: URL.self) { urls, _ in
            shelf.add(urls)
            return !urls.isEmpty
        } isTargeted: { isTargeted = $0 }
    }
}
