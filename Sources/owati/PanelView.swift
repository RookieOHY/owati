import SwiftUI

// 面板交互状态
final class PanelState: ObservableObject {
    static let shared = PanelState()
    @Published var unitIndex = 0          // 剩余 0 ml 1 L 2 升
    @Published var showCountdown = false  // 下次提醒 时刻 <-> 倒计时
    // 假数据 下次提醒按启动时间+间隔算 之后由提醒器接管
    let nextRemind = Date().addingTimeInterval(45 * 60)
}

// 面板主体
struct PanelView: View {
    @ObservedObject var state = PanelState.shared
    @ObservedObject var config = AppConfig.shared

    // 假数据 喝水量 之后接喝水记录
    private let consumedML = 1080.0

    static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEE"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()
    static let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in // 秒级时钟 驱动日期和倒计时
            VStack(spacing: 16) {
                // 左上角 今天 + 日期注脚
                HStack(alignment: .firstTextBaseline) {
                    Text("今日")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(Self.dayFormat.string(from: ctx.date))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                // 圆形进度
                WaveRing(progress: consumedML / Double(config.dailyGoalML),
                         consumedML: consumedML, goalML: config.dailyGoalML)
                Spacer()
                // 两张卡
                HStack(spacing: 10) {
                    remainCard
                    remindCard(ctx.date)
                }
                // 底部 按钮 + 分隔线 + 退出 参考HealthTick的排法
                VStack(spacing: 14) {
                    Button(action: { OwatiApp.showOnboarding() }) {
                        VStack(spacing: 2) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 13))
                            Text("设置")
                                .font(.system(size: 9))
                        }
                        .frame(width: 36, height: 32)
                        .foregroundColor(.primary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.horizontal, 4)
                    Button { NSApp.terminate(nil) } label: {
                        Text("退出 owati")
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.75))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 14)
        }
        .frame(width: 240, height: 380)
    }

    // 左卡 剩余量 点击换单位
    var remainCard: some View {
        let remain = Double(config.dailyGoalML) - consumedML
        return panelCard("剩余", remainText(remain))
            .onTapGesture { state.unitIndex = (state.unitIndex + 1) % 3 }
    }

    // 右卡 下次提醒 点击切倒计时
    func remindCard(_ now: Date) -> some View {
        panelCard("下次提醒", remindText(now))
            .onTapGesture { state.showCountdown.toggle() }
    }

    func panelCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    // 剩余文案 ml / L / 升 轮换
    func remainText(_ remain: Double) -> String {
        switch state.unitIndex {
        case 1: return String(format: "%.2f L", remain / 1000)
        case 2: return String(format: "%.2f 升", remain / 1000)
        default: return "\(Int(remain)) ml"
        }
    }

    // 提醒文案 时刻 / 倒计时
    func remindText(_ now: Date) -> String {
        guard state.showCountdown else {
            return " \(Self.timeFormat.string(from: state.nextRemind))"
        }
        let s = max(0, Int(state.nextRemind.timeIntervalSince(now)))
        return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }
}

// 圆形进度 外圈弧线 里头装波浪
struct WaveRing: View {
    var progress: Double
    var consumedML: Double
    var goalML: Int

    var body: some View {
        ZStack {
            // 圆内底色 亮暗外观都衬文字
            Circle().fill(.primary.opacity(0.05))
            // 外圈进度弧
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.15), style: StrokeStyle(lineWidth: 6))
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [.cyan, .blue, .indigo], center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360 * progress)),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90)) // 从正上方起笔
            }
            .padding(3)
            // 波浪 双层 一深一浅错开动 (实现思路参考 MIT 库 SwiftUI-Motion-Library 的 LiquidFillText)
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                ZStack {
                    WaveShape(level: progress, phase: t * 2.2 + 1.3, amplitude: 4)
                        .fill(.cyan.opacity(0.3))
                    WaveShape(level: progress, phase: t * 3.1 + 3.8, amplitude: 5.5)
                        .fill(LinearGradient(colors: [.blue.opacity(0.7), .cyan.opacity(0.85)],
                                             startPoint: .top, endPoint: .bottom))
                }
                .animation(.spring(duration: 0.9, bounce: 0.25), value: progress)
            }
            .clipShape(Circle())
            .padding(6)
            // 中央 百分比 + 喝了多少
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("\(Int(consumedML)) / \(goalML) ml")
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundColor(.primary)
        }
        .frame(width: 120, height: 120)
    }
}

// 正弦水面 线以下填满
struct WaveShape: Shape {
    var level: Double     // 0 底 1 顶
    var phase: Double
    var amplitude: CGFloat

    nonisolated var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    nonisolated func path(in rect: CGRect) -> Path {
        let baseline = rect.maxY - rect.height * level
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: baseline))
        // 沿正弦走 每隔4pt取一点
        let steps = max(8, Int(rect.width / 4))
        for s in 0...steps {
            let x = rect.minX + rect.width * CGFloat(s) / CGFloat(steps)
            let y = baseline + amplitude * sin(x / rect.width * 2 * .pi * 1.5 + phase)
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}


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
