import AppKit
import QuickLookThumbnailing
import SwiftUI

/// 文件区里的一个图标：缩略图 + 文件名。双击打开，可以拖出去，右键有菜单。
struct FileIconView: View {
    let item: ShelfItem
    /// nil 表示原文件找不到了
    let url: URL?

    @Environment(ShelfStore.self) private var shelf
    @State private var thumbnail: NSImage?
    @State private var showDuePicker = false
    @State private var pickedDate = Date.now

    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: thumbnail ?? fallbackIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
                .opacity(url == nil ? 0.35 : 1)
            Text(item.displayName)
                .font(Theme.Fonts.caption)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
            if url == nil {
                Text("File not found").font(Theme.Fonts.caption).foregroundStyle(.red)
            } else if let due = item.dueDate {
                Text(DueFormatter.relative(due))
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(DueFormatter.isOverdue(due, hasTime: false) ? Color.red : Color.secondary)
            }
        }
        .frame(width: 78)
        .contentShape(Rectangle())
        .help(url?.path ?? item.displayName)
        .onTapGesture(count: 2) { shelf.open(item) }
        .onDrag {
            url.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
        }
        .contextMenu { menu }
        .popover(isPresented: $showDuePicker) { duePicker }
        .task(id: url) { await loadThumbnail() }
    }

    @ViewBuilder
    private var menu: some View {
        Button("Open") { shelf.open(item) }.disabled(url == nil)
        Button("Show in Finder") { shelf.revealInFinder(item) }.disabled(url == nil)
        Divider()
        Menu("Set Due Date") {
            Button("Today") { shelf.setDue(DueFormatter.endOfDay(daysFromToday: 0), for: item.id) }
            Button("Tomorrow") { shelf.setDue(DueFormatter.endOfDay(daysFromToday: 1), for: item.id) }
            Button("In 3 Days") { shelf.setDue(DueFormatter.endOfDay(daysFromToday: 3), for: item.id) }
            Button("In a Week") { shelf.setDue(DueFormatter.endOfDay(daysFromToday: 7), for: item.id) }
            Button("Custom…") {
                pickedDate = item.dueDate ?? .now
                showDuePicker = true
            }
        }
        if item.dueDate != nil {
            Button("Clear Due Date") { shelf.setDue(nil, for: item.id) }
        }
        Divider()
        Button("Remove from Shelf") { shelf.remove(item.id) }
    }

    private var duePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker("Due", selection: $pickedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Spacer()
                Button("Cancel") { showDuePicker = false }
                Button("Done") {
                    let cal = Calendar.current
                    let due = cal.date(bySettingHour: 23, minute: 59, second: 0, of: pickedDate) ?? pickedDate
                    shelf.setDue(due, for: item.id)
                    showDuePicker = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    private var fallbackIcon: NSImage {
        if let url { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSWorkspace.shared.icon(for: .data)
    }

    /// 和 Finder 一样的缩略图（PDF 显示首页）
    private func loadThumbnail() async {
        guard let url else {
            thumbnail = nil
            return
        }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 104, height: 104),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        request.iconMode = true
        if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            thumbnail = rep.nsImage
        }
    }
}
