import AppKit
import SwiftUI

/// 面板根视图。字体和间距统一在 Theme.swift。
struct DashboardView: View {
    @Environment(PanelController.self) private var panel

    var body: some View {
        VStack(spacing: 0) {
            if !panel.isLocked {
                DragHandle()
            }
            ScrollView {
                VStack(spacing: Theme.Layout.cardSpacing) {
                    HeaderCard()
                    WeatherCard()
                    CalendarCard()
                    RemindersCard()
                    DueSoonCard()
                }
                .padding(Theme.Layout.panelPadding)
            }
            .scrollIndicators(.never)
        }
        // 面板里没单独指定字体的文字都默认用 Avenir Next
        .font(Theme.Fonts.body)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FrostedGlassBackground(cornerRadius: 18))
    }
}

/// 磨砂背景：模糊由 WindowServer 做（见 WindowBlur）。
/// WindowServer 只模糊窗口里"有像素"的地方，完全透明的像素不会被模糊，
/// 所以这里铺一层肉眼看不出颜色的圆角底（2% 黑），整块面板才会被模糊，圆角也跟着这个形状走。
private struct FrostedGlassBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(Color.black.opacity(0.02))
            .overlay(shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

/// 面板没锁定时顶部的拖动条
private struct DragHandle: View {
    var body: some View {
        ZStack {
            WindowDragArea()
            HStack(spacing: 6) {
                Capsule().frame(width: 36, height: 4)
                Text("Drag to move · Resize from edges · Lock in menu bar")
                    .font(Theme.Fonts.caption)
            }
            .foregroundStyle(.secondary)
            .allowsHitTesting(false)
        }
        .frame(height: 22)
    }
}

/// 鼠标按下时拖动整个窗口
private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
