import AppKit

// 找到 MenuBarExtra 的宿主窗口去掉系统底色 玻璃圆角才能干净地自己画
func clearHostWindowBackground() {
    for w in NSApp.windows {
        // 向导窗口是titled 跳过 菜单栏小图标窗口不够高 跳过
        if w.styleMask.contains(.titled) || w.frame.height <= 80 { continue }
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
    }
}
