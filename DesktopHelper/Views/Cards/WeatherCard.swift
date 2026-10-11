import SwiftUI

struct WeatherCard: View {
    @Environment(WeatherService.self) private var weather

    var body: some View {
        Card("Weather", systemImage: "cloud.sun", accessory: weather.snapshot?.placeName) {
            if let s = weather.snapshot {
                current(s)
                hourly(s)
                Divider()
                daily(s)
            } else if weather.isLoading {
                ProgressView().controlSize(.small).padding(.leading, Theme.Layout.textInset)
            }
            if let error = weather.errorMessage {
                HStack(spacing: 6) {
                    Text(error).font(Theme.Fonts.caption).foregroundStyle(.secondary)
                    SettingsLink { Text("Settings") }.font(Theme.Fonts.caption)
                }
                .padding(.leading, Theme.Layout.textInset)
            }
        }
    }

    /// 当前天气：图标 | 温度 + 描述 | 今日最高最低（右对齐）
    private func current(_ s: WeatherSnapshot) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: WeatherCode.symbol(s.code, isDay: s.isDay))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 34))
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(Int(s.temperature.rounded()))\(s.unitSymbol)").font(Theme.Fonts.temperature)
                Text(WeatherCode.description(s.code)).font(Theme.Fonts.detail).foregroundStyle(.secondary)
            }
            Spacer()
            if let today = s.days.first {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("H \(Int(today.high.rounded()))°")
                    Text("L \(Int(today.low.rounded()))°").foregroundStyle(.secondary)
                }
                .font(Theme.Fonts.detail)
                .monospacedDigit()
            }
        }
    }

    /// 接下来 6 小时，等宽分栏，铺满卡片宽度
    private func hourly(_ s: WeatherSnapshot) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(s.hours.prefix(6).enumerated()), id: \.element.id) { index, hour in
                VStack(spacing: 4) {
                    Text(index == 0 ? "Now" : hour.time.formatted(.dateTime.hour().locale(AppLocale.locale)))
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: WeatherCode.symbol(hour.code))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 15))
                        .frame(height: 18)
                    Text("\(Int(hour.temperature.rounded()))°").font(Theme.Fonts.detail)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// 未来三天：星期 | 降水概率 | 图标 | 最低 | 最高，每列固定宽度上下对齐
    private func daily(_ s: WeatherSnapshot) -> some View {
        VStack(spacing: Theme.Layout.rowSpacing) {
            ForEach(s.days.dropFirst().prefix(3)) { day in
                HStack(spacing: Theme.Layout.gap) {
                    Text(day.date, format: .dateTime.weekday(.wide).locale(AppLocale.locale))
                        .font(Theme.Fonts.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Group {
                        if let rain = day.precipitationProbability, rain > 0 {
                            Text("\(rain)%").foregroundStyle(.blue)
                        } else {
                            Text("")
                        }
                    }
                    .font(Theme.Fonts.caption)
                    .frame(width: 34, alignment: .trailing)
                    Image(systemName: WeatherCode.symbol(day.code))
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 24)
                    Text("\(Int(day.low.rounded()))°")
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                    Text("\(Int(day.high.rounded()))°")
                        .frame(width: 30, alignment: .trailing)
                }
                .font(Theme.Fonts.detail)
                .monospacedDigit()
            }
        }
    }
}
