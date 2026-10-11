import AppKit
import SwiftUI

/// 创建并管理桌面面板：显示/隐藏、锁定、位置保存。
@MainActor
@Observable
final class PanelController {
    private static let frameAutosaveName = "DesktopHelperPanel"

    @ObservationIgnored private var panel: DesktopPanel?

    private(set) var isVisible = false

    var isLocked: Bool = UserDefaults.standard.bool(forKey: SettingsKey.panelLocked) {
        didSet {
            UserDefaults.standard.set(isLocked, forKey: SettingsKey.panelLocked)
            applyLock()
        }
    }

    /// 背景模糊半径，越大越磨砂、越看不清后面的桌面
    var blurRadius: Double = UserDefaults.standard.double(forKey: SettingsKey.panelBlurRadius) {
        didSet {
            UserDefaults.standard.set(blurRadius, forKey: SettingsKey.panelBlurRadius)
            applyBlur()
        }
    }

    func show() {
        if panel == nil { makePanel() }
        panel?.orderFrontRegardless()
        // 模糊要在窗口显示（拿到 windowNumber）之后才能设置
        applyBlur()
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func resetPosition() {
        panel?.setFrame(Self.defaultFrame(), display: true, animate: true)
    }

    private func makePanel() {
        let panel = DesktopPanel(contentRect: Self.defaultFrame())
        let host = NSHostingView(rootView: DashboardView().appEnvironment())
        // 面板大小由窗口决定，不让 SwiftUI 内容反过来撑大窗口
        host.sizingOptions = []
        panel.contentView = host
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        panel.setFrameUsingName(Self.frameAutosaveName)
        self.panel = panel
        applyLock()
    }

    private func applyBlur() {
        guard let panel else { return }
        WindowBlur.apply(radius: Int(blurRadius), to: panel)
    }

    private func applyLock() {
        guard let panel else { return }
        if isLocked {
            panel.styleMask.remove(.resizable)
        } else {
            panel.styleMask.insert(.resizable)
        }
    }

    /// 默认放在主屏幕右上角
    private static func defaultFrame() -> NSRect {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width: CGFloat = 340
        let height = min(visible.height - 40, 820)
        return NSRect(x: visible.maxX - width - 20, y: visible.maxY - height - 20, width: width, height: height)
    }
}
