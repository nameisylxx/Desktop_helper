import AppKit

/// 用 WindowServer 的私有接口给窗口背后加高斯模糊（iTerm2 的背景模糊用的也是它）。
/// 只有模糊，没有任何底色；模糊半径可调。
/// 用 dlsym 动态查找，系统没有这个接口时什么也不做，不会崩溃。
enum WindowBlur {
    private typealias MainConnectionFn = @convention(c) () -> UInt32
    private typealias SetBlurFn = @convention(c) (UInt32, UInt32, Int32) -> Int32

    private static let handle = dlopen(nil, RTLD_NOW)
    private static let mainConnection: MainConnectionFn? = symbol("CGSMainConnectionID")
    private static let setBlurRadius: SetBlurFn? = symbol("CGSSetWindowBackgroundBlurRadius")

    private static func symbol<T>(_ name: String) -> T? {
        guard let ptr = dlsym(handle, name) else { return nil }
        return unsafeBitCast(ptr, to: T.self)
    }

    /// 设置窗口背景模糊半径，0 表示不模糊。窗口需要已经显示过（有 windowNumber）。
    @discardableResult
    static func apply(radius: Int, to window: NSWindow) -> Bool {
        guard let mainConnection, let setBlurRadius, window.windowNumber > 0 else { return false }
        return setBlurRadius(mainConnection(), UInt32(window.windowNumber), Int32(radius)) == 0
    }
}
