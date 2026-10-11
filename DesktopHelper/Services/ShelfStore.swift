import AppKit
import Foundation

/// Due Soon 文件区：保存文件书签，解析出当前路径，持久化到 Application Support。
@MainActor
@Observable
final class ShelfStore {
    private(set) var items: [ShelfItem] = []
    /// 能找到的文件 → 当前 URL；找不到的不在这里面
    private(set) var resolvedURLs: [UUID: URL] = [:]

    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private var monitorTask: Task<Void, Never>?

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DesktopHelper", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storeURL = dir.appendingPathComponent("shelf.json")
        load()
    }

    /// 有 due 的按日期在前，没 due 的按添加时间（新的在前）
    var sortedItems: [ShelfItem] {
        items.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?): x < y
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): a.addedAt > b.addedAt
            }
        }
    }

    func url(for item: ShelfItem) -> URL? {
        resolvedURLs[item.id]
    }

    /// 定期重新解析书签，Finder 里移动/改名/删除后图标会跟着更新
    func startMonitoring() {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                self?.refreshResolution()
            }
        }
    }

    // MARK: - 增删改

    func add(_ urls: [URL]) {
        var existing = Set(resolvedURLs.values.map(\.standardizedFileURL.path))
        for url in urls where url.isFileURL {
            let path = url.standardizedFileURL.path
            guard !existing.contains(path), let bookmark = try? url.bookmarkData() else { continue }
            let item = ShelfItem(id: UUID(), bookmark: bookmark, displayName: url.lastPathComponent, dueDate: nil, addedAt: .now)
            items.append(item)
            resolvedURLs[item.id] = url
            existing.insert(path)
        }
        save()
    }

    /// 只从文件区移除，不会删除原文件
    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        resolvedURLs[id] = nil
        save()
    }

    func setDue(_ date: Date?, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].dueDate = date
        save()
    }

    func open(_ item: ShelfItem) {
        refreshResolution()
        guard let url = url(for: item) else { return }
        NSWorkspace.shared.open(url)
    }

    func revealInFinder(_ item: ShelfItem) {
        guard let url = url(for: item) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - 书签解析

    func refreshResolution() {
        var changed = false
        var map: [UUID: URL] = [:]
        for index in items.indices {
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: items[index].bookmark,
                options: [.withoutUI, .withoutMounting],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ),
                FileManager.default.fileExists(atPath: url.path),
                !url.path.contains("/.Trash/")
            else { continue }

            map[items[index].id] = url
            if stale, let fresh = try? url.bookmarkData() {
                items[index].bookmark = fresh
                changed = true
            }
            if items[index].displayName != url.lastPathComponent {
                items[index].displayName = url.lastPathComponent
                changed = true
            }
        }
        if map != resolvedURLs { resolvedURLs = map }
        if changed { save() }
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([ShelfItem].self, from: data)) ?? []
        refreshResolution()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
