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
    private let db = Database.shared

    // 今日已喝 真数据 来自SQLite
    private var consumedML: Double { Double(db.todayTotalML()) }

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
                // 圆环 + 环下三列数据
                VStack(spacing: 12) {
                    WaveRing(progress: consumedML / Double(config.dailyGoalML),
                             consumedML: consumedML, goalML: config.dailyGoalML)
                    // 三列数据
                    HStack(spacing: 0) {
                        statCol("\(db.todayCups()) 杯", "杯数")
                        statCol("\(db.streakDays(goalML: config.dailyGoalML)) 天", "连续")
                        statCol(db.lastDrinkText() ?? "—", "距上次")
                    }
                    statusLine
                    weekDrops
                }
                // 两张卡
                HStack(spacing: 10) {
                    remainCard
                    remindCard(ctx.date)
                }
                // 底部 分隔线 + 按钮排
                VStack(spacing: 14) {
                    Divider().padding(.horizontal, 4)
                    HStack(spacing: 0) {
                        controlButton("统计", "chart.xyaxis.line", "1") { /* 统计页后续做 */ }
                        controlButton("成就", "trophy", "2") { /* 成就页后续做 */ }
                        controlButton("帮助", "questionmark.circle", "3") { /* 帮助页后续做 */ }
                        controlButton("设置", "gear", "4") { OwatiApp.showOnboarding() }
                        controlButton("退出", "power", "q") { NSApp.terminate(nil) }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 14)
        }
        // 宽度固定 高度随内容自动撑 定高会在内容变化时把上下裁掉
        .frame(width: 240)
    }

    // 底栏按钮 图标+小字
    func controlButton(_ title: String, _ icon: String, _ key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(.system(size: 9))
            }
            .frame(width: 36, height: 32)
            .foregroundColor(.primary.opacity(0.5))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(key.first!), modifiers: .command)
        .frame(maxWidth: .infinity)
    }

    // 三列数据列 数值带单位+名词标签
    func statCol(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // 状态行 随进度换文案 图标点题
    var statusLine: some View {
        let cups = db.todayCups()
        let consumed = Int(consumedML)
        let goal = config.dailyGoalML
        return HStack(spacing: 5) {
            if cups == 0 {
                Image(systemName: "drop.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("来第一杯水，开启今天")
                    .foregroundColor(.secondary)
            } else if consumed >= goal {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                Text("今日目标已达成，连续 \(db.streakDays(goalML: goal)) 天")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "target")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("离 今日目标 还差 ")
                    .foregroundColor(.secondary)
                Text("\(goal - consumed) ml")
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
            }
        }
        .font(.system(size: 12))
    }

    // 本周水滴 一天一滴 滴内是当天杯数 滴下是几号 周一开头
    var weekDrops: some View {
        let cal = Calendar(identifier: .iso8601) // 周一为一周开始
        let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())!.start
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        let counts = db.cupsByDate(dates: days.map { Database.dayFormat.string(from: $0) })
        return HStack(spacing: 5) {
            ForEach(Array(days.enumerated()), id: \.offset) { pair in
                let d = pair.element
                let isToday = cal.isDateInToday(d)
                let n = counts[Database.dayFormat.string(from: d), default: 0]
                VStack(spacing: 4) {
                    ZStack {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(isToday ? AnyShapeStyle(Color.accentColor)
                                                      : AnyShapeStyle(Color.primary.opacity(0.12)))
                        if n > 0 {
                            Text("\(n)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(isToday ? .white : .primary.opacity(0.6))
                                .offset(y: -1)
                        }
                    }
                    VStack(spacing: 2) {
                        Text("\(Calendar.current.component(.day, from: d))")
                            .font(.system(size: 9))
                            .foregroundColor(isToday ? Color.accentColor : .secondary)
                        // 今天的号下面一条小蓝线
                        Capsule()
                            .fill(isToday ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.clear))
                            .frame(width: 8, height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // 左卡 剩余量 点击换单位
    var remainCard: some View {
        let remain = Double(config.dailyGoalML) - consumedML
        return panelCard("剩余水量", remainText(remain))
            .onTapGesture { state.unitIndex = (state.unitIndex + 1) % 3 }
    }

    // 右卡 下次提醒 点击切倒计时 标签跟着变
    func remindCard(_ now: Date) -> some View {
        panelCard(state.showCountdown ? "倒计时" : "下次提醒", remindText(now))
            .onTapGesture { state.showCountdown.toggle() }
    }

    func panelCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
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
            return Self.timeFormat.string(from: state.nextRemind)
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
            // 波浪 双层 一深一浅错开动
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
