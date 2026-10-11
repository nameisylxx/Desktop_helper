import SwiftUI

/// 所有卡片共用的外框：标题图标在标记列，标题文字在正文列，右边可放一个补充说明
struct Card<Content: View>: View {
    let title: String
    let systemImage: String
    let accessory: String?
    @ViewBuilder let content: Content

    init(_ title: String, systemImage: String, accessory: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.blockSpacing) {
            MarkerRow {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
            } content: {
                Text(title).font(Theme.Fonts.cardTitle)
            } trailing: {
                if let accessory {
                    Text(accessory)
                        .font(Theme.Fonts.cardAccessory)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Layout.cardPadding)
        .background(GlassCardBackground())
    }
}

/// 卡片：不加底色，只用一圈细线分区
private struct GlassCardBackground: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
    }
}

/// 没有权限时显示的提示
struct AccessPrompt: View {
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message).font(Theme.Fonts.detail).foregroundStyle(.secondary)
            Button(buttonTitle, action: action)
        }
        .padding(.leading, Theme.Layout.textInset)
    }
}

/// 空状态文字，和正文左边对齐
struct EmptyNote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.Fonts.detail)
            .foregroundStyle(.secondary)
            .padding(.leading, Theme.Layout.textInset)
    }
}
