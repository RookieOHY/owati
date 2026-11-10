import SwiftUI

// 程序入口
@main
struct OwatiApp: App {
    init() {
        // 加载水滴图标 44px 显示成 22pt
        let path = (#filePath as NSString).deletingLastPathComponent + "/../../demo/png/owati-44.png"
        let icon = NSImage(contentsOfFile: path)!
        icon.size = NSSize(width: 22, height: 22)
        // 纯黑+透明 系统自动适配亮色暗色菜单栏
        icon.isTemplate = true
        menuIcon = icon
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

    private let menuIcon: NSImage

    var body: some Scene {
        // 菜单栏水滴 点击弹出面板
        MenuBarExtra {
            PanelView()
        } label: {
            Image(nsImage: menuIcon)
        }
        .menuBarExtraStyle(.window) // 面板模式 不是菜单模式
    }
}

// 磨砂玻璃背景（SwiftUI 自带的 Material 在这里会发黑 只能用 AppKit 的）
struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground // 透出面板后面的东西
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

// 面板 暂时空白 内容后面加
struct PanelView: View {
    var body: some View {
        VStack {}
            .frame(width: 300, height: 380)
            .background(GlassBackground())
    }
}
