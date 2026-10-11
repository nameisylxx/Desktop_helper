import AppKit

/// 贴在桌面上的无边框面板：在桌面图标之上、所有普通窗口之下，每个桌面空间都显示。
final class DesktopPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // 背景完全透明时，系统默认会让点击穿透透明像素到桌面上；
        // 显式设成 false，整个面板区域都能接收点击和拖动
        ignoresMouseEvents = false
        // 普通窗口之下的最高一层：在桌面图标之上（图标会被一起模糊掉），但不会挡住任何 App 窗口
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        // 只有点到输入框之类需要键盘的控件时才成为 key window
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = false
        minSize = NSSize(width: 280, height: 320)
    }

    // 允许面板里的输入框接收键盘输入
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
