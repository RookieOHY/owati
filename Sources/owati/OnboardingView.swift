import SwiftUI

// 向导步骤状态
final class OnboardingState: ObservableObject {
    @Published var step = 0
}

// 四步设置向导 参考HealthTick 蓝色主题
struct OnboardingView: View {
    @ObservedObject var config = AppConfig.shared
    @ObservedObject var state = OnboardingState()
    // 宿主窗口 完成时关闭
    static weak var window: NSWindow?

    private let dayOrder = [2, 3, 4, 5, 6, 7, 1]           // 显示顺序 一二三四五六日
    private let dayNames = [1: "日", 2: "一", 3: "二", 4: "三", 5: "四", 6: "五", 7: "六"]

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏 进度点 + 跳过
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { i in
                        Capsule()
                            .fill(i <= state.step ? Color.accentColor : Color.gray.opacity(0.25))
                            .frame(width: i == state.step ? 20 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.25), value: state.step)
                    }
                }
                Spacer()
                Button("跳过") { finish() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 8)

            // 内容区 每步一页
            Group {
                switch state.step {
                case 0: goalPage
                case 1: intervalPage
                case 2: daysPage
                case 3: timePage
                case 4: restPage
                default: summaryPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)

            // 底栏 返回 / 下一步 / 完成
            HStack {
                if state.step > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { state.step -= 1 }
                    } label: {
                        Label("返回", systemImage: "chevron.left")
                            .font(.callout)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                Spacer()
                if state.step < 5 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { state.step += 1 }
                    } label: {
                        Label("下一步", systemImage: "chevron.right")
                            .labelStyle(.titleAndIcon)
                            .font(.callout.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.gradient, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        finish()
                    } label: {
                        Label("完成", systemImage: "checkmark")
                            .labelStyle(.titleAndIcon)
                            .font(.callout.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.gradient, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .frame(width: 460, height: 420)
    }

    // 第1页 每日喝水目标
    private var goalPage: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .foregroundColor(.accentColor)
                Text("每天喝多少水？")
                    .font(.system(size: 20, weight: .bold))
            }
            Text("\(config.dailyGoalML) ml")
                .font(.system(size: 44, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.accentColor)
                .padding(.top, 8)
            Slider(value: Binding(
                get: { Double(config.dailyGoalML) },
                set: { config.dailyGoalML = Int($0) }
            ), in: 500...4000, step: 250)
                .padding(.top, 18)
            HStack {
                Text("500ml"); Spacer(); Text("4000ml")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            HStack(spacing: 8) {
                ForEach([1500, 2000, 2500], id: \.self) { v in
                    Button { config.dailyGoalML = v } label: {
                        Text("\(v)")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 64, height: 30)
                            .foregroundStyle(config.dailyGoalML == v ? .white : .primary.opacity(0.7))
                            .background(
                                config.dailyGoalML == v ? Color.accentColor : Color.gray.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)
            Spacer()
        }
    }

    // 第2页 提醒间隔
    private var intervalPage: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .foregroundColor(.accentColor)
                Text("隔多久提醒一次？")
                    .font(.system(size: 20, weight: .bold))
            }
            Text("\(config.remindIntervalMin) 分钟")
                .font(.system(size: 44, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.accentColor)
                .padding(.top, 8)
            Slider(value: Binding(
                get: { Double(config.remindIntervalMin) },
                set: { config.remindIntervalMin = Int($0) }
            ), in: 15...120, step: 5)
                .padding(.top, 18)
            HStack {
                Text("15分钟"); Spacer(); Text("2小时")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            HStack(spacing: 8) {
                ForEach([30, 45, 60, 90], id: \.self) { v in
                    Button { config.remindIntervalMin = v } label: {
                        Text("\(v)分")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 56, height: 30)
                            .foregroundStyle(config.remindIntervalMin == v ? .white : .primary.opacity(0.7))
                            .background(
                                config.remindIntervalMin == v ? Color.accentColor : Color.gray.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)
            Spacer()
        }
    }

    // 第3页 提醒日
    private var daysPage: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.accentColor)
                Text("哪几天提醒？")
                    .font(.system(size: 20, weight: .bold))
            }
                .padding(.bottom, 24)
            // 7天选择块
            HStack(spacing: 6) {
                ForEach(dayOrder, id: \.self) { day in
                    Button {
                        if config.remindDays.contains(day) {
                            if config.remindDays.count > 1 {   // 至少保留一天
                                config.remindDays.remove(day)
                            }
                        } else {
                            config.remindDays.insert(day)
                        }
                    } label: {
                        Text(dayNames[day] ?? "")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 42, height: 32)
                            .foregroundStyle(config.remindDays.contains(day) ? .white : .primary.opacity(0.6))
                            .background(
                                config.remindDays.contains(day) ? Color.accentColor : Color.gray.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            // 快捷全选
            HStack(spacing: 10) {
                quickDayButton("工作日", icon: "briefcase.fill", set: [2, 3, 4, 5, 6])
                quickDayButton("每天", icon: "repeat", set: [1, 2, 3, 4, 5, 6, 7])
                quickDayButton("清空", icon: "arrow.counterclockwise", set: [])
            }
            .padding(.top, 16)
            Spacer()
        }
    }

    func quickDayButton(_ title: String, icon: String, set: Set<Int>) -> some View {
        Button { config.remindDays = set } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
    }

    // 第4页 时间范围 + 总结
    private var timePage: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(.accentColor)
                Text("什么时间段提醒？")
                    .font(.system(size: 20, weight: .bold))
            }
                .padding(.bottom, 20)
            // 两行装进同一张卡片 中间分隔线
            VStack(spacing: 0) {
                HStack {
                    iconLabel("开始", "bell.fill")
                    Spacer()
                    DatePicker("", selection: dateBinding(\.remindStart),
                               displayedComponents: .hourAndMinute)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                Divider().padding(.leading, 42)
                HStack {
                    iconLabel("结束", "bell.slash.fill")
                    Spacer()
                    DatePicker("", selection: dateBinding(\.remindEnd),
                               displayedComponents: .hourAndMinute)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            Text("时间段外不打扰你")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 10)
            Spacer()
        }
    }

    // "HH:mm"字符串 <-> Date
    func dateBinding(_ keyPath: ReferenceWritableKeyPath<AppConfig, String>) -> Binding<Date> {
        Binding(
            get: {
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                return f.date(from: config[keyPath: keyPath]) ?? Date()
            },
            set: {
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                config[keyPath: keyPath] = f.string(from: $0)
            }
        )
    }

    // 第5页 休息时间 段内不提醒
    private var restPage: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(.accentColor)
                Text("休息时间")
                    .font(.system(size: 20, weight: .bold))
            }
                .padding(.bottom, 8)
            Text("休息时间段内不会提醒你喝水")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
            VStack(spacing: 0) {
                // 启用开关
                HStack {
                    iconLabel("启用午间休息", "moon.fill")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { config.restEnabled },
                        set: { config.restEnabled = $0 }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                Divider().padding(.leading, 42)
                HStack {
                    iconLabel("开始", "cup.and.saucer")
                    Spacer()
                    DatePicker("", selection: dateBinding(\.restStart),
                               displayedComponents: .hourAndMinute)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                Divider().padding(.leading, 42)
                HStack {
                    iconLabel("结束", "briefcase.fill")
                    Spacer()
                    DatePicker("", selection: dateBinding(\.restEnd),
                               displayedComponents: .hourAndMinute)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            .opacity(config.restEnabled ? 1 : 0.45)   // 关闭时整块置灰
            .disabled(!config.restEnabled)
            Spacer()
        }
    }

    // 图标定宽 让各行文字左对齐
    func iconLabel(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 18)
            Text(title)
        }
        .font(.callout)
    }

    // 第6页 汇总
    private var summaryPage: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.accentColor.gradient)
            Text("设置完成")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 10)
            // 汇总卡片
            VStack(spacing: 0) {
                summaryRow("target", .blue, "每日目标", "\(config.dailyGoalML) ml")
                Divider().padding(.leading, 44)
                summaryRow("bell.fill", .orange, "提醒间隔", "\(config.remindIntervalMin) 分钟")
                Divider().padding(.leading, 44)
                summaryRow("calendar", .green, "提醒日", daysText)
                Divider().padding(.leading, 44)
                summaryRow("clock.fill", .purple, "时间段", "\(config.remindStart) - \(config.remindEnd)")
                Divider().padding(.leading, 44)
                summaryRow("cup.and.saucer.fill", .teal, "休息时间",
                           config.restEnabled ? "\(config.restStart) - \(config.restEnd)" : "未启用")
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            .padding(.top, 20)
            Text("设置以后可以在面板里修改")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 10)
            Spacer()
        }
    }

    // 提醒日文案
    private var daysText: String {
        let sorted = config.remindDays.sorted()
        if sorted.isEmpty { return "未设置" }
        if sorted == [2, 3, 4, 5, 6] { return "周一至周五" }
        if sorted == [1, 2, 3, 4, 5, 6, 7] { return "每天" }
        return sorted.compactMap { dayNames[$0] }.map { "周\($0)" }.joined(separator: "、")
    }

    // 汇总行 彩色图标+标签+粗体数值
    func summaryRow(_ icon: String, _ color: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 20)
            Text(label)
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.callout.bold().monospacedDigit())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // 完成引导
    func finish() {
        config.didOnboarding = true
        Self.window?.close()
    }
}
