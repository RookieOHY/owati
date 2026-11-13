import SwiftUI

// 设置窗口 点底栏设置弹出 独立窗口 Obsidian式: 侧栏分区+侧栏顶部搜索
enum SettingsWindow {
    static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 780, height: 640),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
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
            // 面板app常处于未激活状态 不激活的话窗口弹不到最前
            NSApp.activate(ignoringOtherApps: true)
            w.orderFrontRegardless()
            w.makeKeyAndOrderFront(nil)
        }
    }
}

// 可搜索到的设置项 搜索命中后跳对应分区
struct SettingsEntry {
    let title: String
    let keywords: String
    let onSelect: () -> Void
}

// 品牌蓝 不跟系统强调色走(系统选灰时界面全灰)
extension Color {
    static let owAccent = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
}

struct SettingsView: View {
    @ObservedObject var cfg = AppConfig.shared
    @ObservedObject var state = PanelState.shared

    var body: some View {
        HStack(spacing: 0) {
            // 侧栏 满高浅色底 顶部搜索 分区在下
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    TextField("搜索设置…", text: $state.settingsSearch)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 6)
                tabBtn("通用", "gearshape", 0)
                tabBtn("关于", "info.circle", 1)
                Spacer()
            }
            .padding(12)
            .frame(width: 184)
            .background(Color.primary.opacity(0.03))
            Divider()
            // 内容区 分区内容
            VStack(alignment: .leading, spacing: 16) {
                if state.settingsSearch.isEmpty {
                    switch state.settingsTab {
                    case 1: aboutPane
                    default: generalPane
                    }
                } else {
                    searchResults
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
        }
        .onAppear {
            // 开着自动更新就顺手查一次
            if cfg.checkUpdates && state.updateStatus.isEmpty { runUpdateCheck() }
        }
    }

    // 搜索命中的设置项 列出来 点了跳到通用对应位置
    private var entries: [SettingsEntry] {
        var es: [SettingsEntry] = [
            SettingsEntry(title: "外观", keywords: "外观 浅色 深色 主题") { state.settingsTab = 0 },
            SettingsEntry(title: "开机自启动", keywords: "自启动 开机 登录 启动") { state.settingsTab = 0 },
            SettingsEntry(title: "自动检查更新", keywords: "更新 升级 版本 检查") { state.settingsTab = 0 },
            SettingsEntry(title: "设置引导", keywords: "向导 引导 设置") { state.settingsTab = 0 },
        ]
        es += Sfx.allCases.map { s in
            SettingsEntry(title: "音效 · \(s.title)", keywords: "音效 试听 \(s.title) \(s.rawValue)") {
                state.settingsTab = 0
                cfg.soundEffect = s.rawValue
                SoundPlayer.shared.preview(s)
            }
        }
        es += [
            SettingsEntry(title: "音效 · 开关", keywords: "音效 开关 声音 静音") { state.settingsTab = 0 },
            SettingsEntry(title: "提醒 · 间隔", keywords: "提醒 间隔 分钟 频率 节奏") { state.settingsTab = 0 },
            SettingsEntry(title: "提醒 · 时间段", keywords: "提醒 时间段 开始 结束 起止") { state.settingsTab = 0 },
            SettingsEntry(title: "提醒 · 提醒日", keywords: "提醒 日 星期 工作日 周末") { state.settingsTab = 0 },
            SettingsEntry(title: "提醒 · 休息段", keywords: "休息 午休 不提醒") { state.settingsTab = 0 },
            SettingsEntry(title: "关于 · 版本", keywords: "关于 版本") { state.settingsTab = 1 },
        ]
        return es
    }

    private var searchResults: some View {
        let q = state.settingsSearch.lowercased()
        let hits = entries.filter { $0.title.lowercased().contains(q) || $0.keywords.lowercased().contains(q) }
        return VStack(alignment: .leading, spacing: 4) {
            if hits.isEmpty {
                Text("没有匹配的设置")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            ForEach(Array(hits.enumerated()), id: \.offset) { _, e in
                Button {
                    e.onSelect()
                } label: {
                    HStack {
                        Text(e.title)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
    }

    // 侧栏按钮
    private func tabBtn(_ title: String, _ icon: String, _ idx: Int) -> some View {
        Button {
            state.settingsTab = idx
            state.settingsSearch = ""
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                state.settingsTab == idx
                    ? AnyShapeStyle(Color.owAccent.opacity(0.18))
                    : AnyShapeStyle(Color.clear),
                in: RoundedRectangle(cornerRadius: 8))
            .foregroundColor(
                state.settingsTab == idx ? .owAccent : Color.primary.opacity(0.75))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.top, 4)
    }

    // Apple设置风的行 彩色圆角图标+标题+右侧控件
    private func settingsRow(_ icon: String, _ color: Color, _ title: String, @ViewBuilder _ control: () -> some View) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white))
            Text(title)
                .font(.system(size: 13))
            Spacer()
            control()
        }
        .padding(.vertical, 7)
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
        TextField("09:00", text: text)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12, weight: .medium))
            .frame(width: 60)
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

    // MARK: 通用页
    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("提醒节奏")
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
            settingsRow("clock", .blue, "提醒时间段") {
                HStack(spacing: 4) {
                    timeField($cfg.remindStart)
                    Text("–").foregroundColor(.secondary).font(.system(size: 12))
                    timeField($cfg.remindEnd)
                }
            }
            settingsRow("calendar", .mint, "提醒日") {
                HStack(spacing: 5) {
                    ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { d in
                        weekdayChip(d)
                    }
                }
            }
            settingsRow("moon.zzz", .indigo, "休息段") {
                switchToggle($cfg.restEnabled)
            }
            // 关了休息段 时间段灰掉禁点
            HStack {
                Text("休息时间段")
                    .font(.system(size: 13))
                    .opacity(cfg.restEnabled ? 1 : 0.4)
                Spacer()
                HStack(spacing: 4) {
                    timeField($cfg.restStart)
                    Text("–").foregroundColor(.secondary).font(.system(size: 12))
                    timeField($cfg.restEnd)
                }
                .opacity(cfg.restEnabled ? 1 : 0.4)
                .allowsHitTesting(cfg.restEnabled)
            }
            .padding(.leading, 36)
            .padding(.vertical, 4)
            Divider().padding(.vertical, 4)
            sectionTitle("通用")
            settingsRow("circle.lefthalf.filled", .purple, "外观") {
                popup(["跟随系统", "浅色", "深色"], cfg.appearance) { cfg.appearance = $0 }
            }
            Divider()
            settingsRow("power", .green, "开机自启动") {
                switchToggle($cfg.launchAtLogin)
            }
            Divider()
            // 检查更新结果文案挂在行下
            VStack(alignment: .leading, spacing: 2) {
                settingsRow("arrow.triangle.2.circlepath", .teal, "自动检查更新") {
                    switchToggle($cfg.checkUpdates) { on in if on { runUpdateCheck() } }
                }
                if !state.updateStatus.isEmpty {
                    Text(state.updateStatus)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 36)
                }
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
            Divider().padding(.vertical, 4)
            sectionTitle("记录音效")
            // 开关挂标题行 少一层结构
            HStack {
                Text("音效")
                    .font(.system(size: 13))
                Spacer()
                switchToggle($cfg.soundOn) { on in
                    if on { SoundPlayer.shared.preview(selected) }   // 打开顺便试听一声
                }
            }
            .padding(.leading, 36)
            .padding(.vertical, 5)
            // 关了开关选项收起 省得看着一堆不可用的设置
            if cfg.soundOn {
                ForEach(Sfx.allCases, id: \.rawValue) { s in
                    Button {
                        cfg.soundEffect = s.rawValue
                        SoundPlayer.shared.preview(s)
                    } label: {
                        HStack {
                            Image(systemName: "speaker.wave.1")
                                .font(.system(size: 11))
                                .foregroundColor(cfg.soundEffect == s.rawValue ? .owAccent : .secondary)
                            Text(s.title)
                                .font(.system(size: 13))
                                .foregroundColor(cfg.soundEffect == s.rawValue ? .owAccent : .primary)
                            Spacer()
                            if cfg.soundEffect == s.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.owAccent)
                            }
                        }
                        .padding(.leading, 36)
                        .padding(.vertical, 8)
                        .background(
                            cfg.soundEffect == s.rawValue
                                ? AnyShapeStyle(Color.owAccent.opacity(0.08))
                                : AnyShapeStyle(Color.clear),
                            in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: cfg.soundOn)
        .frame(maxWidth: 560, alignment: .leading)
    }

    // MARK: 关于页
    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.owAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("owati")
                        .font(.system(size: 17, weight: .semibold))
                    Text("菜单栏喝水提醒 · 久坐也别忘")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 8)
            settingsRow("info.circle", .gray, "版本") {
                Text(Self.version).font(.system(size: 13)).foregroundColor(.secondary)
            }
            Divider().padding(.vertical, 4)
            Text("在菜单栏养一只喝水小管家")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 560, alignment: .leading)
    }

    // 查GitHub最新release和当前版本比对 零依赖实现检查更新
    private func runUpdateCheck() {
        state.updateStatus = "检查中…"
        let cur = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard let url = URL(string: "https://api.github.com/repos/RookieOHY/owati/releases/latest") else { return }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        Task {
            var s = "暂时检查不了 稍后再试"
            if let (data, _) = try? await URLSession.shared.data(for: req),
               let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let tag = obj["tag_name"] as? String {
                s = !cur.isEmpty && tag.contains(cur) ? "已是最新版本 \(tag)" : "发现新版本 \(tag)"
            }
            await MainActor.run { state.updateStatus = s }
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
