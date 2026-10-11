import Foundation

/// 一次天气查询的结果，会缓存到 UserDefaults，断网时显示上次的数据
struct WeatherSnapshot: Codable, Equatable {
    struct Hour: Codable, Equatable, Identifiable {
        var id: Date { time }
        let time: Date
        let temperature: Double
        let code: Int
    }

    struct Day: Codable, Equatable, Identifiable {
        var id: Date { date }
        let date: Date
        let code: Int
        let high: Double
        let low: Double
        let precipitationProbability: Int?
    }

    let placeName: String
    let temperature: Double
    let apparentTemperature: Double?
    let code: Int
    let isDay: Bool
    let unitSymbol: String
    let hours: [Hour]
    let days: [Day]
    let fetchedAt: Date
}

/// Open-Meteo 城市搜索结果
struct GeoPlace: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?

    var subtitle: String {
        [admin1, country].compactMap { $0 }.joined(separator: ", ")
    }
}

/// WMO 天气代码 → 中文描述 + SF Symbol
enum WeatherCode {
    static func description(_ code: Int) -> String {
        switch code {
        case 0: "Clear"
        case 1: "Mostly Clear"
        case 2: "Partly Cloudy"
        case 3: "Overcast"
        case 45, 48: "Fog"
        case 51, 53, 55: "Drizzle"
        case 56, 57: "Freezing Drizzle"
        case 61: "Light Rain"
        case 63: "Rain"
        case 65: "Heavy Rain"
        case 66, 67: "Freezing Rain"
        case 71: "Light Snow"
        case 73: "Snow"
        case 75: "Heavy Snow"
        case 77: "Snow Grains"
        case 80, 81: "Showers"
        case 82: "Heavy Showers"
        case 85, 86: "Snow Showers"
        case 95: "Thunderstorm"
        case 96, 99: "Thunderstorm with Hail"
        default: "Unknown"
        }
    }

    static func symbol(_ code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1: isDay ? "sun.max.fill" : "moon.fill"
        case 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55: "cloud.drizzle.fill"
        case 56, 57, 66, 67: "cloud.sleet.fill"
        case 61, 63: "cloud.rain.fill"
        case 65, 82: "cloud.heavyrain.fill"
        case 80, 81: isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 71, 73, 75, 77, 85, 86: "cloud.snow.fill"
        case 95: "cloud.bolt.fill"
        case 96, 99: "cloud.bolt.rain.fill"
        default: "questionmark"
        }
    }
}
