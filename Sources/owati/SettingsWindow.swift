import SwiftUI

// 设置窗 转正期间Dock会亮图标 关窗切回accessory
final class SettingsPanelWindow: NSWindow, NSWindowDelegate {
    override var canBecomeKey: Bool { true }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// 设置窗口 点底栏设置弹出 独立窗口
enum SettingsWindow {
    static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = SettingsPanelWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 640),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            w.delegate = w
            w.title = "设置"
            w.isReleasedWhenClosed = false
            // 菜单栏app的普通窗口会被钉在别的空间 全屏应用里点了也看不见
            // 跟随当前空间+可悬浮全屏应用上方+浮动层级 才和向导一样指哪打哪
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            w.level = .floating
            w.setFrameAutosaveName("owatiSettings")   // 记住位置
            w.contentView = NSHostingView(rootView: SettingsView())
            window = w
        }
        if let w = window {
            if w.isMiniaturized { w.deminiaturize(nil) }
            // 临时转正 accessory的键盘焦点被系统吞 打字/步进进不来
            // regular期间有Dock图标+正常焦点 关窗切回accessory
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            w.orderFrontRegardless()
            w.makeKeyAndOrderFront(nil)
        }
    }
}

// 品牌蓝 不跟系统强调色走(系统选灰时界面全灰)
extension Color {
    static let owAccent = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
}

struct SettingsView: View {
    @ObservedObject var cfg = AppConfig.shared
    @ObservedObject var state = PanelState.shared

    var body: some View {
        VStack(spacing: 0) {
            // 顶部居中胶囊Tab容器 纯文本选中灰胶囊 HealthTick同款
            HStack {
                Spacer()
                HStack(spacing: 2) {
                    tabBtn("通用", 0)
                    tabBtn("关于", 1)
                }
                .padding(3)
                .background(Color.primary.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
                Spacer()
            }
            .padding(.top, 10)
            .padding(.bottom, 12)
            // 内容 懒加载 只构建当前tab
            Group {
                if state.settingsTab == 0 {
                    generalPane
                } else {
                    aboutPane
                }
            }
        }
        .frame(width: 640)
        .padding(.bottom, 12)
    }

    // 顶部Tab按钮 纯文本 选中灰胶囊 居中容器
    private func tabBtn(_ title: String, _ idx: Int) -> some View {
        Button {
            state.settingsTab = idx
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(
                    state.settingsTab == idx
                        ? AnyShapeStyle(Color.primary.opacity(0.14))
                        : AnyShapeStyle(Color.clear),
                    in: RoundedRectangle(cornerRadius: 6))
                .foregroundColor(state.settingsTab == idx ? .primary : Color.primary.opacity(0.65))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // 卡片小灰标题 HealthTick: 11pt secondary 缩进10
    private func sectionHeader(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .padding(.bottom, -4)
    }

    // Apple设置风的行 彩色圆角图标+标题+右侧控件 HealthTick: 横14竖7 图标24
    private func settingsRow(_ icon: String, _ color: Color, _ title: String, @ViewBuilder _ control: () -> some View) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color.gradient)
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white))
            Text(title)
                .font(.callout)
            Spacer()
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // 右侧弹选 popup样式
    private func popup(_ options: [String], _ idx: Int, _ pick: @escaping (Int) -> Void) -> some View {
        Menu {
            ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                Button(i == idx ? "✓ \(o)" : o) { pick(i) }
            }
        } label: {
            HStack(spacing: 5) {
                Text(options[idx]).font(.system(size: 12))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // 小圆步进按钮 -/+ 用
    private func stepBtn(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.primary.opacity(0.6))
                .frame(width: 22, height: 22)
                .background(Color.primary.opacity(0.08), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // 自绘拨杆 系统Toggle的tint在这套环境不吃 统一画法蓝色稳
    private func switchToggle(_ on: Binding<Bool>, onChange: @escaping (Bool) -> Void = { _ in }) -> some View {
        Button {
            on.wrappedValue.toggle()
            onChange(on.wrappedValue)
        } label: {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(on.wrappedValue ? Color.owAccent : Color.primary.opacity(0.22))
                    .frame(width: 38, height: 22)
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                    .offset(x: on.wrappedValue ? 18 : 2)
            }
            .animation(.easeInOut(duration: 0.15), value: on.wrappedValue)
        }
        .buttonStyle(.plain)
    }

    private func timeField(_ text: Binding<String>) -> some View {
        // HealthTick同款 原生DatePicker 只显示时:分
        DatePicker("", selection: Binding(
            get: { dateFromHHmm(text.wrappedValue) },
            set: { text.wrappedValue = hhmmFromDate($0) }
        ), displayedComponents: .hourAndMinute)
        .labelsHidden()
        .fixedSize()
    }

    // "HH:mm" <-> Date 只取当天时分
    private func dateFromHHmm(_ str: String) -> Date {
        let parts = str.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return Date() }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = parts[0]
        comps.minute = parts[1]
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func hhmmFromDate(_ date: Date) -> String {
        let cal = Calendar.current
        return String(format: "%02d:%02d", cal.component(.hour, from: date), cal.component(.minute, from: date))
    }

    private func weekdayChip(_ d: Int) -> some View {
        let names = [1: "日", 2: "一", 3: "二", 4: "三", 5: "四", 6: "五", 7: "六"]
        return Button {
            if cfg.remindDays.contains(d) { cfg.remindDays.remove(d) } else { cfg.remindDays.insert(d) }
        } label: {
            Text(names[d] ?? "")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 28)
                .background(
                    cfg.remindDays.contains(d)
                        ? AnyShapeStyle(Color.owAccent.opacity(0.15))
                        : AnyShapeStyle(Color.primary.opacity(0.05)),
                    in: RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(cfg.remindDays.contains(d) ? Color.owAccent : .clear, lineWidth: 1))
                .foregroundColor(cfg.remindDays.contains(d) ? .owAccent : .secondary)
        }
        .buttonStyle(.plain)
    }

    // 通用页 每个设置卡片 HealthTick式: 小灰标题+圆角卡片装行 分割线从图标后开始
    private var generalPane: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("提醒")
                VStack(spacing: 0) {
                    settingsRow("calendar", .mint, "提醒日") {
                        HStack(spacing: 5) {
                            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { d in
                                weekdayChip(d)
                            }
                        }
                    }
                    Divider()
                    settingsRow("clock.badge.checkmark", .orange, "提醒间隔") {
                        HStack(spacing: 6) {
                            stepBtn("minus") { cfg.remindIntervalMin = max(5, cfg.remindIntervalMin - 5) }
                            Text("\(cfg.remindIntervalMin) 分钟")
                                .font(.system(size: 12, weight: .medium))
                                .monospacedDigit()
                                .frame(minWidth: 62)
                            stepBtn("plus") { cfg.remindIntervalMin = min(240, cfg.remindIntervalMin + 5) }
                        }
                    }
                    Divider()
                    settingsRow("clock", .blue, "提醒时间段") {
                        HStack(spacing: 4) {
                            timeField($cfg.remindStart)
                            Text("–").foregroundColor(.secondary).font(.system(size: 12))
                            timeField($cfg.remindEnd)
                        }
                    }
                    Divider()
                    settingsRow("moon.zzz", .indigo, "勿扰模式") {
                        switchToggle($cfg.restEnabled)
                    }
                    Divider()
                    settingsRow("moon", .indigo, "勿扰时间段") {
                        HStack(spacing: 4) {
                            timeField($cfg.restStart)
                            Text("–").foregroundColor(.secondary).font(.system(size: 12))
                            timeField($cfg.restEnd)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                sectionHeader("通用")
                    .padding(.top, 4)
                VStack(spacing: 0) {
                    settingsRow("circle.lefthalf.filled", .purple, "外观") {
                        popup(["跟随系统", "浅色", "深色"], cfg.appearance) { cfg.appearance = $0 }
                    }
                    Divider()
                    settingsRow("power", .green, "开机自启动") {
                        switchToggle($cfg.launchAtLogin)
                    }
                    Divider()
                    settingsRow("wand.and.stars", .pink, "设置引导") {
                        Button {
                            OwatiApp.showOnboarding()
                        } label: {
                            Text("打开")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.owAccent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                sectionHeader("音效")
                    .padding(.top, 4)
                VStack(spacing: 0) {
                    settingsRow("speaker.wave.1", .blue, "音效开关") {
                        switchToggle($cfg.soundOn) { on in
                            if on { SoundPlayer.shared.preview(selected) }   // 打开顺便试听一声
                        }
                    }
                    Divider()
                    settingsRow("music.note", .indigo, "音效选择") {
                        let all = Sfx.allCases
                        let idx = all.firstIndex(of: Sfx(rawValue: cfg.soundEffect) ?? .canFizz) ?? 0
                        popup(all.map { $0.title }, idx) { i in
                            cfg.soundEffect = all[i].rawValue
                            SoundPlayer.shared.preview(all[i])
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
        }
    }

    // MARK: 关于页 卡片式
    private var aboutPane: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("关于")
                VStack(spacing: 0) {
                    settingsRow("drop.fill", .blue, "owati") {
                        Text(Self.version).font(.callout).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
        }
    }

    // 当前选中的音效 开关行试听用
    private var selected: Sfx {
        Sfx(rawValue: cfg.soundEffect) ?? .canFizz
    }

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "开发版"
    }
}

