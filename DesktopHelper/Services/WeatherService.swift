import AppKit
import Foundation

/// 用 Open-Meteo 查天气（免费、无需 API key）。每 30 分钟刷新，电脑唤醒后也刷新。
@MainActor
@Observable
final class WeatherService {
    private static let refreshInterval: Duration = .seconds(30 * 60)

    private(set) var snapshot: WeatherSnapshot?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let location: LocationService
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?

    init(location: LocationService) {
        self.location = location
        if let data = UserDefaults.standard.data(forKey: SettingsKey.weatherCache) {
            snapshot = try? JSONDecoder().decode(WeatherSnapshot.self, from: data)
        }
    }

    func start() {
        guard timerTask == nil else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        guard let place = await resolvePlace() else { return }
        do {
            let unit = TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: SettingsKey.temperatureUnit) ?? "") ?? .celsius
            let result = try await Self.fetchForecast(latitude: place.latitude, longitude: place.longitude, name: place.name, unit: unit)
            snapshot = result
            errorMessage = nil
            if let data = try? JSONEncoder().encode(result) {
                UserDefaults.standard.set(data, forKey: SettingsKey.weatherCache)
            }
        } catch {
            errorMessage = "Weather update failed: \(error.localizedDescription)"
        }
    }

    /// 选定的城市保存到设置里，并立即刷新
    func setCity(_ place: GeoPlace) {
        let defaults = UserDefaults.standard
        defaults.set(place.name, forKey: SettingsKey.weatherCityName)
        defaults.set(place.latitude, forKey: SettingsKey.weatherLatitude)
        defaults.set(place.longitude, forKey: SettingsKey.weatherLongitude)
        Task { await refresh() }
    }

    /// 优先用当前位置；定位失败时退回设置里选的城市
    private func resolvePlace() async -> (latitude: Double, longitude: Double, name: String)? {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: SettingsKey.weatherUseLocation) {
            do {
                let loc = try await location.currentLocation()
                return (loc.coordinate.latitude, loc.coordinate.longitude, "Current Location")
            } catch {
                errorMessage = "\(error.localizedDescription), using the city from Settings"
            }
        }
        if let name = defaults.string(forKey: SettingsKey.weatherCityName),
           defaults.object(forKey: SettingsKey.weatherLatitude) != nil {
            return (defaults.double(forKey: SettingsKey.weatherLatitude), defaults.double(forKey: SettingsKey.weatherLongitude), name)
        }
        errorMessage = "Choose a city in Settings, or allow location access"
        return nil
    }

    // MARK: - Open-Meteo API

    static func searchPlaces(_ query: String) async throws -> [GeoPlace] {
        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comps.queryItems = [
            .init(name: "name", value: query),
            .init(name: "count", value: "10"),
            .init(name: "language", value: "en"),
            .init(name: "format", value: "json"),
        ]
        struct Response: Decodable { let results: [GeoPlace]? }
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        return try JSONDecoder().decode(Response.self, from: data).results ?? []
    }

    private static func fetchForecast(latitude: Double, longitude: Double, name: String, unit: TemperatureUnit) async throws -> WeatherSnapshot {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            .init(name: "hourly", value: "temperature_2m,weather_code"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime"),
            .init(name: "forecast_days", value: "7"),
            .init(name: "temperature_unit", value: unit.rawValue),
        ]
        let (data, response) = try await URLSession.shared.data(from: comps.url!)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        let r = try JSONDecoder().decode(ForecastResponse.self, from: data)

        let now = Date.now
        var hours: [WeatherSnapshot.Hour] = []
        for (i, t) in r.hourly.time.enumerated() {
            let time = Date(timeIntervalSince1970: t)
            guard time > now.addingTimeInterval(-3600),
                  let temp = r.hourly.temperature_2m[safe: i] ?? nil,
                  let code = r.hourly.weather_code[safe: i] ?? nil else { continue }
            hours.append(.init(time: time, temperature: temp, code: code))
            if hours.count == 12 { break }
        }

        var days: [WeatherSnapshot.Day] = []
        for (i, t) in r.daily.time.enumerated() {
            guard let code = r.daily.weather_code[safe: i] ?? nil,
                  let high = r.daily.temperature_2m_max[safe: i] ?? nil,
                  let low = r.daily.temperature_2m_min[safe: i] ?? nil else { continue }
            let rain = r.daily.precipitation_probability_max?[safe: i] ?? nil
            days.append(.init(date: Date(timeIntervalSince1970: t), code: code, high: high, low: low, precipitationProbability: rain))
        }

        return WeatherSnapshot(
            placeName: name,
            temperature: r.current.temperature_2m,
            apparentTemperature: r.current.apparent_temperature,
            code: r.current.weather_code,
            isDay: r.current.is_day == 1,
            unitSymbol: r.current_units?.temperature_2m ?? (unit == .celsius ? "°C" : "°F"),
            hours: hours,
            days: days,
            fetchedAt: now
        )
    }

    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let apparent_temperature: Double?
            let weather_code: Int
            let is_day: Int
        }
        struct Units: Decodable {
            let temperature_2m: String
        }
        struct Hourly: Decodable {
            let time: [TimeInterval]
            let temperature_2m: [Double?]
            let weather_code: [Int?]
        }
        struct Daily: Decodable {
            let time: [TimeInterval]
            let weather_code: [Int?]
            let temperature_2m_max: [Double?]
            let temperature_2m_min: [Double?]
            let precipitation_probability_max: [Int?]?
        }

        let current: Current
        let current_units: Units?
        let hourly: Hourly
        let daily: Daily
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
