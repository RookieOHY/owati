import SwiftUI

// 浮动提醒卡 不抢键盘焦点 到点轻拍肩膀 30秒自动消失
final class ReminderCard {
    static let shared = ReminderCard()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(text: String) {
        let p = ensurePanel()
        PanelState.shared.remindCardText = text
        PanelState.shared.remindCardVisible = true
        // 定位 主屏右上 菜单栏正下方
        if let s = NSScreen.main {
            let menubar = s.frame.maxY - s.visibleFrame.maxY
            let size = p.frame.size
            p.setFrame(NSRect(x: s.frame.maxX - size.width - 12,
                              y: s.frame.maxY - menubar - size.height - 6,
                              width: size.width, height: size.height),
                       display: true)
        }
        p.orderFrontRegardless()
        // 30秒自动消失
        hideWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: w)
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        panel?.orderOut(nil)
        PanelState.shared.remindCardVisible = false
    }

    // borderless+nonactivating 弹出不激活app 键盘焦点留在原app
    private func ensurePanel() -> NSPanel {
        if let p = panel { return p }
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 224, height: 96),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating
        // 全屏应用上方也可见 不随空间走
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.contentView = NSHostingView(rootView: ReminderCardView())
        panel = p
        return p
    }
}

struct ReminderCardView: View {
    @ObservedObject var state = PanelState.shared
    private let db = Database.shared

    var body: some View {
        let goal = db.todayGoalOverride() ?? AppConfig.shared.dailyGoalML
        let total = db.todayTotalML()
        let frac = goal > 0 ? min(1, Double(total) / Double(goal)) : 0
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                // 水滴坐圆底座 和面板chip同款视觉
                ZStack {
                    Circle()
                        .fill(Color.owAccent.opacity(0.14))
                        .frame(width: 34, height: 34)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.owAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.remindCardText)
                        .font(.system(size: 13, weight: .semibold))
                    // 数值上蓝 剩余灰
                    (Text("今日已摄入 ").foregroundColor(.secondary)
                        + Text("\(total)").foregroundColor(.owAccent).fontWeight(.semibold)
                        + Text(" / ").foregroundColor(.secondary)
                        + Text("\(goal)").foregroundColor(.owAccent).fontWeight(.semibold)
                        + Text(" ml").foregroundColor(.secondary))
                        .font(.system(size: 10))
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            // 今日进度细条 数字变了平滑推进
            Capsule()
                .fill(Color.owAccent.opacity(0.12))
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.owAccent)
                        .frame(width: max(6, 200 * frac))
                }
                .animation(.easeOut(duration: 0.35), value: total)
            HStack(spacing: 8) {
                Button {
                    PanelState.shared.quickLogCup()
                } label: {
                    Text("记一杯")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color.owAccent, in: Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    PanelState.shared.snoozeCard()
                } label: {
                    Text("稍后")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 224, height: 96, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.08)))
    }
}
