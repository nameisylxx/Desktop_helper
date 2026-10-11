import SwiftUI

@main
struct DesktopHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Desktop Helper", systemImage: "calendar.badge.clock") {
            MenuBarContent()
                .appEnvironment()
        }

        Settings {
            SettingsView()
                .appEnvironment()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.start()
    }
}

/// 菜单栏图标下拉菜单
private struct MenuBarContent: View {
    @Environment(PanelController.self) private var panel
    @Environment(EventKitService.self) private var eventKit
    @Environment(WeatherService.self) private var weather
    @Environment(ShelfStore.self) private var shelf

    var body: some View {
        Button(panel.isVisible ? "Hide Desktop Panel" : "Show Desktop Panel") { panel.toggle() }
        Toggle("Lock Position and Size", isOn: Binding(get: { panel.isLocked }, set: { panel.isLocked = $0 }))
        Button("Reset Panel Position") { panel.resetPosition() }
        Divider()
        Button("Refresh Now") {
            shelf.refreshResolution()
            Task {
                await eventKit.refresh()
                await weather.refresh()
            }
        }
        .keyboardShortcut("r")
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Divider()
        Button("Quit Desktop Helper") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
