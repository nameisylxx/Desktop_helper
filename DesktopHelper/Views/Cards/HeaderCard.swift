import SwiftUI

struct HeaderCard: View {
    private static let amPM: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.locale
        f.dateFormat = "a"
        return f
    }()

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 0) {
                // 大号时间 + 小号 AM/PM，按基线对齐
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(context.date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute().locale(AppLocale.locale))
                        .font(Theme.Fonts.clock)
                    Text(Self.amPM.string(from: context.date))
                        .font(Theme.Fonts.clockSuffix)
                        .foregroundStyle(.secondary)
                }
                Text(context.date, format: .dateTime.weekday(.wide).month(.wide).day().year().locale(AppLocale.locale))
                    .font(Theme.Fonts.date)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // 和卡片内容的左边对齐
            .padding(.horizontal, Theme.Layout.cardPadding)
            .padding(.top, 2)
        }
    }
}
