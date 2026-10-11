import SwiftUI

/// 持有所有 Service 的单例，App 启动时创建一次。
@MainActor
final class AppModel {
    static let shared = AppModel()

    let location: LocationService
    let eventKit: EventKitService
    let weather: WeatherService
    let shelf: ShelfStore
    let panel: PanelController

    private init() {
        SettingsKey.registerDefaults()
        location = LocationService()
        eventKit = EventKitService()
        weather = WeatherService(location: location)
        shelf = ShelfStore()
        panel = PanelController()
    }

    func start() {
        panel.show()
        shelf.startMonitoring()
        weather.start()
        Task { await eventKit.start() }
    }
}

extension View {
    /// 把所有 Service 注入到 SwiftUI 环境里，面板、菜单栏、设置窗口共用。
    @MainActor
    func appEnvironment() -> some View {
        let model = AppModel.shared
        return environment(model.eventKit)
            .environment(model.weather)
            .environment(model.shelf)
            .environment(model.panel)
            .environment(\.locale, AppLocale.locale)
    }
}
