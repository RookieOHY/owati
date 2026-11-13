import SwiftUI

// 程序入口
@main
struct OwatiApp: App {
    @ObservedObject var ui = PanelState.shared
    private let menuIcon: NSImage
    init() {
        // 加载水滴图标 44px 显示成 22pt Retina整2倍不糊
        let icon = Res.path("demo/png/owati-44.png").flatMap { NSImage(contentsOfFile: $0) }
            ?? NSImage(size: NSSize(width: 22, height: 22)) // 找不到给空占位 引擎1秒内接管
        icon.size = NSSize(width: 22, height: 22)
        // 纯黑+透明 系统自动适配亮色暗色菜单栏
        icon.isTemplate = true
        menuIcon = icon
        // 动态菜单栏图标的初始帧 静态水滴 引擎1秒内接管渲染
        PanelState.shared.menuBarImage = icon
        // 确保数据库已开
        _ = Database.shared
        // 提醒引擎 进程级常驻
        PanelState.shared.startRemindEngine()
        // 首次启动 弹出四步设置向导
        if !AppConfig.shared.didOnboarding {
            DispatchQueue.main.async { Self.showOnboarding() }
        }
    }

    static func showOnboarding() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.title = "欢迎使用 owati"
        w.appearance = NSAppearance(named: .darkAqua) // 锁定深色外观 日期控件不再是刺眼白底
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: OnboardingView())
        w.center()
        w.level = .floating
        OnboardingView.window = w
        w.makeKeyAndOrderFront(nil)
    }

    var body: some Scene {
        // 菜单栏水滴 点击弹出面板 图标动态渲染(进度环+倒计时)
        MenuBarExtra {
            PanelView()
        } label: {
            Image(nsImage: ui.menuBarImage)
        }
        .menuBarExtraStyle(.window) // 面板模式 不是菜单模式
    }
}
