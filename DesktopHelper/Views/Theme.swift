import SwiftUI

/// 面板的字体和排版网格。换字体只需要改 `family`。
enum Theme {
    // MARK: - 字体

    enum Weight: String {
        case medium = "Medium"
        case demiBold = "DemiBold"
        case bold = "Bold"
    }

    /// Avenir Next：系统自带，几何感有设计味，但笔画够粗、好读
    static let family = "AvenirNext"

    static func font(_ size: CGFloat, _ weight: Weight = .medium, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("\(family)-\(weight.rawValue)", size: size, relativeTo: style)
    }

    enum Fonts {
        static let clock = Theme.font(46, .demiBold, relativeTo: .largeTitle)
        static let clockSuffix = Theme.font(16, .demiBold, relativeTo: .title3)
        static let date = Theme.font(14, .medium, relativeTo: .subheadline)
        static let cardTitle = Theme.font(15, .bold, relativeTo: .headline)
        static let cardAccessory = Theme.font(12, .medium, relativeTo: .caption)
        static let sectionLabel = Theme.font(10.5, .bold, relativeTo: .caption2)
        static let body = Theme.font(13.5, .medium, relativeTo: .body)
        static let detail = Theme.font(12, .medium, relativeTo: .callout)
        static let caption = Theme.font(11, .medium, relativeTo: .caption)
        static let temperature = Theme.font(30, .demiBold, relativeTo: .title)
    }

    // MARK: - 网格

    enum Layout {
        /// 面板外边距
        static let panelPadding: CGFloat = 12
        /// 卡片内边距，时钟也用这个，让时钟和卡片内容左边对齐
        static let cardPadding: CGFloat = 14
        static let cardSpacing: CGFloat = 10
        /// 卡片里各块之间
        static let blockSpacing: CGFloat = 12
        /// 同一组里行与行之间
        static let rowSpacing: CGFloat = 7
        /// 左边的标记列（卡片标题图标、日程圆点、待办圆圈、Due 图标都在这一列，居中对齐）
        static let markerColumn: CGFloat = 16
        /// 标记列和文字之间的间距；所有文字都从 markerColumn + gap 开始
        static let gap: CGFloat = 8
        static var textInset: CGFloat { markerColumn + gap }
    }
}

/// 分组小标题（TODAY / TOMORROW …），和正文左边对齐
struct SectionLabel: View {
    let text: String
    var color: Color = .secondary

    init(_ text: String, color: Color = .secondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(Theme.Fonts.sectionLabel)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.leading, Theme.Layout.textInset)
    }
}

/// 标准的一行：左边标记列 + 文字 + 右对齐的补充信息
struct MarkerRow<Marker: View, Content: View, Trailing: View>: View {
    @ViewBuilder let marker: Marker
    @ViewBuilder let content: Content
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Layout.gap) {
            marker.frame(width: Theme.Layout.markerColumn)
            content.frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
    }
}

extension MarkerRow where Trailing == EmptyView {
    init(@ViewBuilder marker: () -> Marker, @ViewBuilder content: () -> Content) {
        self.marker = marker()
        self.content = content()
        self.trailing = EmptyView()
    }
}
