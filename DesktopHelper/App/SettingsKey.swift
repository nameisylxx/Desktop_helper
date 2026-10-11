import Foundation

/// UserDefaults 里用到的 key，统一放这里。
enum SettingsKey {
    static let panelLocked = "panelLocked"
    static let panelBlurRadius = "panelBlurRadius"
    static let calendarDays = "calendarDays"
    static let dueSoonDays = "dueSoonDays"
    static let hiddenCalendarIDs = "hiddenCalendarIDs"
    static let defaultReminderListID = "defaultReminderListID"

    static let weatherUseLocation = "weatherUseLocation"
    static let weatherCityName = "weatherCityName"
    static let weatherLatitude = "weatherLatitude"
    static let weatherLongitude = "weatherLongitude"
    static let temperatureUnit = "temperatureUnit"
    static let weatherCache = "weatherCache"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            panelLocked: false,
            panelBlurRadius: 30.0,
            calendarDays: 7,
            dueSoonDays: 7,
            weatherUseLocation: true,
            temperatureUnit: TemperatureUnit.celsius.rawValue,
        ])
    }
}

/// 界面固定用英文，日期时间格式也固定成英文（不跟随系统语言）
enum AppLocale {
    static let locale = Locale(identifier: "en_US")
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: Self { self }
    var label: String { self == .celsius ? "Celsius °C" : "Fahrenheit °F" }
}
