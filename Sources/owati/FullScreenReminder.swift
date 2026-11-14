import SwiftUI

// 全屏提醒 可选的提醒方式 覆盖所有显示器
// 不抢键盘焦点(nonactivating) 30s自动关闭 中央卡: 标题/tips/进度/快捷量/稍后
final class FullScreenReminder {
    static let shared = FullScreenReminder()
    private var panels: [NSPanel] = []
    private var hideWork: DispatchWorkItem?

    private var cachedBg: (size: CGSize, image: NSImage)?
    private var themeToken: (any NSObjectProtocol)?

    func show(tip: String) {
        let state = PanelState.shared
        state.fullScreenTip = tip
        state.fullScreenDeadline = Date().addingTimeInterval(30)
        state.fullScreenVisible = true
        state.startFullScreenCountdown()
        ensurePanels()
        installAppearanceObserver()
        rebakeBackground()
        panels.forEach { $0.orderFrontRegardless() }
    }

    // 外观切换(手动深浅色/日落自动切换) 重烘blob位图适配新外观
    private func installAppearanceObserver() {
        guard themeToken == nil, let app = NSApp else { return }
        themeToken = app.observe(\.effectiveAppearance, options: [.initial]) { [weak self] _, _ in
            self?.rebakeBackground(force: true)
        }
    }

    // 背景烘焙 外观变化时force重烘
    private func rebakeBackground(force: Bool = false) {
        let size = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        if force || cachedBg?.size != size {
            cachedBg = (size, Self.renderBlobs(size: size))
        }
        if PanelState.shared.fullScreenVisible {
            PanelState.shared.fullScreenBg = cachedBg?.image
        }
    }

    // 水色blob烘进位图 径向渐变自带柔边 代替blur(90)每帧重算
    private static func renderBlobs(size: CGSize) -> NSImage {
        let img = NSImage(size: size)
        img.lockFocus()
        let blue = NSColor(Color.owAccent)
        let specs: [(color: NSColor, frac: CGFloat, xf: CGFloat, yf: CGFloat)] = [
            (blue, 0.65, 0.5, 0.55),
            (.systemTeal, 0.45, 0.82, 0.2),
            (.systemBlue, 0.45, 0.15, 0.75),
            (.systemCyan, 0.35, 0.2, 0.18),
        ]
        for (c, frac, xf, yf) in specs {
            let r = size.width * frac / 2
            let center = NSPoint(x: size.width * xf, y: size.height * yf)
            let path = NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            let g = NSGradient(colors: [c.withAlphaComponent(0.5), c.withAlphaComponent(0)])!
            g.draw(fromCenter: center, radius: 0,
                   toCenter: center, radius: r, options: [])
        }
        img.unlockFocus()
        return img
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        panels.forEach { $0.orderOut(nil) }
        PanelState.shared.fullScreenVisible = false
        PanelState.shared.stopFullScreenCountdown()
        PanelState.shared.previewing = false
    }

    // 每块屏幕盖一层
    private func ensurePanels() {
        let screens = NSScreen.screens
        // 数量对不上重建 以屏幕为准
        if panels.count != screens.count {
            panels.forEach { $0.orderOut(nil) }
            panels = screens.map { screen in
                let p = NSPanel(
                    contentRect: screen.frame,
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered, defer: false)
                p.isOpaque = false
                p.backgroundColor = .clear
                p.level = .floating
                p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                p.hidesOnDeactivate = false
                p.isReleasedWhenClosed = false
                p.contentView = NSHostingView(rootView: FullScreenReminderView())
                return p
            }
        }
        // 逐屏贴框 显示器排列变了也对上
        for (i, screen) in screens.enumerated() where i < panels.count {
            panels[i].setFrame(screen.frame, display: true)
        }
    }
}

struct FullScreenReminderView: View {
    @ObservedObject var state = PanelState.shared
    private let cfg = AppConfig.shared

    var body: some View {
        ZStack {
            background
            card
        }
        .ignoresSafeArea()
        // 双击背景空白 = 稍后 比找按钮快(卡片区内点击不触发)
        .onTapGesture(count: 2) {
            if !state.previewing {
                PanelState.shared.snoozeCard()
            } else {
                FullScreenReminder.shared.hide()
            }
        }
    }

    // 真原生玻璃 NSVisualEffectView behindWindow磨砂掉背后的真实屏幕
    private struct NativeGlass: NSViewRepresentable {
        func makeNSView(context: Context) -> NSVisualEffectView {
            let v = NSVisualEffectView()
            v.material = .hudWindow
            v.blendingMode = .behindWindow
            v.state = .active
            return v
        }

        func updateNSView(_ v: NSVisualEffectView, context: Context) {}
    }

    // 背景 真玻璃 + 烘焙好的blob静态位图 零每帧成本
    private var background: some View {
        ZStack {
            NativeGlass()
            if let bg = state.fullScreenBg {
                Image(nsImage: bg)
                    .resizable()
            }
        }
        .ignoresSafeArea()
    }

    // 自动关闭徽章 秒数+微进度条 绑引擎发布的剩余秒数
    private struct AutoCloseBadge: View {
        @ObservedObject var state = PanelState.shared

        var body: some View {
            let left = state.fullScreenLeft
            VStack(spacing: 4) {
                Text(state.previewing ? "预览中 · \(left)s 后自动关闭" : "\(left)s 后自动关闭")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.6))
                    .monospacedDigit()
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12)).frame(width: 150, height: 3)
                    Capsule()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: max(4, 150 * CGFloat(left) / 30.0), height: 3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
        }
    }

    // 中央卡
    private var card: some View {
        let goal = Database.shared.todayGoalOverride() ?? cfg.dailyGoalML
        let total = Database.shared.todayTotalML()
        return VStack(spacing: 18) {
            // 顶部自动关闭 剩余秒数+微进度条 引擎1秒Timer驱动
            AutoCloseBadge()
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    // 水滴呼吸+倒水倾角 循环起伏
                    Image(systemName: "drop.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.owAccent)
                        .scaleEffect(state.cardBreath ? 1.18 : 1.0)
                        .rotationEffect(.degrees(state.cardBreath ? 12 : -8))
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: state.cardBreath)
                    Text("该喝水了")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.owAccent)
                }
                .onAppear { state.cardBreath = true }
                // tips 带个小灯泡图标
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(state.fullScreenTip)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(minHeight: 18)
                // 今日进度 数值上蓝
                HStack {
                    (Text("今日已摄入 ").foregroundColor(.secondary)
                        + Text("\(total)ml").foregroundColor(.owAccent).fontWeight(.semibold))
                        .font(.system(size: 11))
                        .monospacedDigit()
                    Spacer()
                    (Text("目标 ").foregroundColor(.secondary)
                        + Text("\(goal)ml").foregroundColor(.owAccent).fontWeight(.semibold))
                        .font(.system(size: 11))
                        .monospacedDigit()
                }
                // 自绘进度条 tint在这套环境不吃
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.owAccent.opacity(0.15))
                        .frame(height: 5)
                    Capsule()
                        .fill(Color.owAccent)
                        .frame(width: max(8, 368 * (goal > 0 ? min(1, Double(total) / Double(goal)) : 0)), height: 5)
                }
                .animation(.easeOut(duration: 0.35), value: total)
                // 快捷量 两个数值: 一杯/一瓶
                HStack(spacing: 12) {
                    ForEach([cfg.cupML, cfg.bottleML].filter { $0 > 0 }, id: \.self) { ml in
                        Button {
                            PanelState.shared.quickLog(ml: ml)
                        } label: {
                            Text("\(ml) ml")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.owAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(nsColor: .windowBackgroundColor).opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
                                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // 稍后
                Button {
                    PanelState.shared.snoozeCard()
                } label: {
                    Text("稍后")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 24)
            .frame(width: 420)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                    .shadow(color: .black.opacity(0.15), radius: 24, y: 8)
            )
        }
    }
}
