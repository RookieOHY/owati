import SwiftUI

// MARK: 顶部居中胶囊Tab HealthTick同款 设置窗/统计窗共用
// 不用@Binding 本机CLT工具链SwiftUI宏插件缺失 项目惯例状态统一进PanelState
struct CapsuleTabs: View {
    let titles: [String]
    let index: Int
    let pick: (Int) -> Void

    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: 2) {
                ForEach(titles.indices, id: \.self) { i in
                    Button {
                        pick(i)
                    } label: {
                        Text(titles[i])
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 5)
                            .background(
                                index == i
                                    ? AnyShapeStyle(Color.primary.opacity(0.14))
                                    : AnyShapeStyle(Color.clear),
                                in: RoundedRectangle(cornerRadius: 6))
                            .foregroundColor(index == i ? .primary : Color.primary.opacity(0.65))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.primary.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
            Spacer()
        }
    }
}

// 统计窗口 点底栏统计弹出 独立窗口 复用设置窗的浮动窗基类
enum StatsWindow {
    static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = FloatingPanelWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 680),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            w.title = "统计"
            w.isReleasedWhenClosed = false
            // 菜单栏app的普通窗口会被钉在别的空间 跟随当前空间+悬浮全屏应用上方
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            w.level = .floating
            w.setFrameAutosaveName("owatiStats")
            w.contentView = NSHostingView(rootView: StatsView())
            window = w
        }
        if let w = window {
            if w.isMiniaturized { w.deminiaturize(nil) }
            // 临时转正 accessory的键盘焦点被系统吞 关窗切回accessory
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            w.orderFrontRegardless()
            w.makeKeyAndOrderFront(nil)
        }
    }
}

// 行尾的? 点击弹详细说明 HealthTick同款 设置窗/统计窗共用
struct HelpMark: View {
    let key: String
    let text: String
    @ObservedObject var state = PanelState.shared

    var body: some View {
        Button {
            state.helpOpen = state.helpOpen == key ? nil : key
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("查看说明")
        .popover(isPresented: Binding(
            get: { state.helpOpen == key },
            set: { if !$0 { state.helpOpen = nil } }
        )) {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .padding(14)
                .frame(width: 250, alignment: .leading)
        }
    }
}

// 单日的统计切片
struct DayStat {
    let date: String
    let ml: Int
    let cups: Int
    let goal: Int
    var met: Bool { ml >= goal }
}

// 饮品类型主色 名称文字与横条同色 SF图标已验证存在
extension DrinkType {
    var tint: Color {
        switch self {
        case .water: return .blue
        case .coffee: return .brown
        case .tea: return .green
        case .milk: return .purple
        case .juice: return .orange
        }
    }

    // 饮品构成卡用SF图标替代emoji
    var symbol: String {
        switch self {
        case .water: return "drop.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .tea: return "leaf.fill"
        case .milk: return "mug.fill"
        case .juice: return "takeoutbag.and.cup.and.straw.fill"
        }
    }
}

// 统计页 结构对齐HealthTick: 指标卡阵 + 柱状图 + 类型/时段分布 + 激励文案
struct StatsView: View {
    @ObservedObject var state = PanelState.shared   // drinkPulse 记一笔立即重算
    @ObservedObject var config = AppConfig.shared
    let db = Database.shared

    static let mdFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()
    static let mdShortFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    var body: some View {
        let _ = state.drinkPulse   // 观察驱动 记一笔/删一笔都重算
        let dates = Self.lastDates(state.statsRange == 0 ? 7 : 30)
        let stats = dayStats(dates)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                CapsuleTabs(titles: ["近7天", "近30天"], index: state.statsRange) { state.statsRange = $0 }
                    .padding(.bottom, 2)
                sectionHeader("概览")
                metricRows(stats)
                barChartCard(stats)
                sectionHeader("饮品构成")
                typeCard(dates)
                footerLine
            }
            .padding(16)
        }
        .frame(width: 640)
    }

    // MARK: 数据组装

    // 近n天日期 升序 末位今天
    static func lastDates(_ n: Int) -> [String] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<n).map { off in
            Database.dayFormat.string(from: cal.date(byAdding: .day, value: -(n - 1 - off), to: today)!)
        }
    }

    static func date(_ s: String) -> Date {
        Database.dayFormat.date(from: s) ?? Date()
    }

    func dayStats(_ dates: [String]) -> [DayStat] {
        let mls = db.mlByDate(dates: dates)
        let cups = db.cupsByDate(dates: dates)
        let goals = db.goalOverrides(dates: dates)
        return dates.map {
            DayStat(date: $0, ml: mls[$0] ?? 0, cups: cups[$0] ?? 0,
                    goal: goals[$0] ?? config.dailyGoalML)
        }
    }

    // 最佳连续 全历史走一遍 断档重开 未达标清零
    func bestStreak() -> Int {
        let days = db.dayTotals()
        guard !days.isEmpty else { return 0 }
        let ov = db.goalOverrides(dates: days.map { $0.date })
        let cal = Calendar.current
        var best = 0, run = 0
        var prev: Date? = nil
        for d in days {
            guard let day = Database.dayFormat.date(from: d.date) else { continue }
            if let p = prev, cal.dateComponents([.day], from: p, to: day).day != 1 { run = 0 }
            prev = day
            let goal = ov[d.date] ?? config.dailyGoalML
            if d.ml >= goal { run += 1; best = max(best, run) } else { run = 0 }
        }
        return best
    }

    // ml格式化 上万转L 免得卡片装不下
    func fmtML(_ ml: Int) -> String {
        ml >= 10000 ? String(format: "%.1f L", Double(ml) / 1000) : "\(ml) ml"
    }

    // MARK: 指标卡阵 HealthTick式 大数字+小标签

    func metricRows(_ stats: [DayStat]) -> some View {
        let active = stats.filter { $0.cups > 0 }
        let cupsSum = stats.reduce(0) { $0 + $1.cups }
        let mlSum = stats.reduce(0) { $0 + $1.ml }
        let metCount = active.filter { $0.met }.count
        let avg = active.isEmpty ? 0 : mlSum / active.count
        let best = active.map { $0.ml }.max() ?? 0
        let rangeName = state.statsRange == 0 ? "近7天" : "近30天"
        let (tv, tu) = cardNum(db.totalAllML())
        let (av, au) = cardNum(avg)
        let (bv, bu) = cardNum(best)
        // 今日卡 Apple Watch训练式 当前值大主色 目标小灰字
        let todayML = db.todayTotalML()
        let todayGoal = db.todayGoalOverride() ?? config.dailyGoalML
        let todayText = Text(todayML.formatted())
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.blue)
            + Text(" / \(todayGoal.formatted())")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            + Text(" ml")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                metricCard("drop.fill", .blue, value: todayText, "今日", id: 0)
                metricCard("flame.fill", .orange, value: hero("\(db.streakDays(goalML: config.dailyGoalML))", "天", .orange), "当前连续达标", id: 1)
                metricCard("crown.fill", .yellow, value: hero("\(bestStreak())", "天", .yellow), "历史最佳连续", id: 2)
                metricCard("sum", .indigo, value: hero(tv, tu, .indigo), "累计水合量", id: 3,
                    help: "水合量是按饮品类型折算后的有效补水量：水 ×1.0、茶 ×0.95、咖啡 ×0.9、牛奶 ×0.9、果汁 ×0.85。\n\n例：250 ml 咖啡记 225。咖啡因利尿，补水效率略低。\n\n面板进度环、连续达标、成就卡都是这个口径。")
            }
            HStack(spacing: 8) {
                metricCard("mug.fill", .cyan, value: hero(cupsSum.formatted(), "杯", .cyan), rangeName, id: 4)
                metricCard("divide", .purple, value: hero(av, au, .purple), "日均 · \(rangeName)", id: 5)
                metricCard("checkmark.seal.fill", .mint, value: hero("\(metCount * 100 / max(1, active.count))%", "", .mint), "达标率 \(metCount)/\(active.count) 天", id: 6)
                metricCard("chart.bar.fill", .pink, value: hero(bv, bu, .pink), "单日最高", id: 7)
            }
        }
    }

    // 单值卡的hero文本 数字大且带卡片主题色(Apple运动式) 单位灰小
    func hero(_ n: String, _ unit: String, _ tint: Color) -> Text {
        Text(n)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(tint)
        + (unit.isEmpty
            ? Text("")
            : Text(" \(unit)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary))
    }

    // 数值+单位拆分 上万转L免得数字过长 其余千分位分组
    func cardNum(_ ml: Int) -> (value: String, unit: String) {
        ml >= 10000
            ? (String(format: "%.1f", Double(ml) / 1000), "L")
            : (ml.formatted(), "ml")
    }

    // Apple健康卡片式 彩色图标+hero数值(层级已由调用方组好)+下方标签 可选尾随问号说明
    // 悬停浮起 App Store卡片同款: 微放大1.035+底部投影 spring回弹 微而快才不廉价
    func metricCard(_ icon: String, _ color: Color, value: Text, _ label: String, id: Int, help: String? = nil) -> some View {
        let hovered = state.statsHoverCard == id
        return VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.gradient)
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white))
            value
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let help {
                    HelpMark(key: label, text: help)
                        .scaleEffect(0.85, anchor: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .scaleEffect(hovered ? 1.035 : 1)
        .shadow(color: .black.opacity(hovered ? 0.16 : 0),
                radius: hovered ? 10 : 0, y: hovered ? 4 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovered)
        .onHover { on in
            state.statsHoverCard = on ? id : (state.statsHoverCard == id ? nil : state.statsHoverCard)
        }
    }

    // MARK: 柱状图 柱顶数值 目标虚线 达标亮/未达标灰 悬停出详情

    func barChartCard(_ stats: [DayStat]) -> some View {
        let maxML = stats.map { $0.ml }.max() ?? 0
        let top = max(maxML, 1)
        return VStack(alignment: .leading, spacing: 8) {
            // 卡内自带标题 与外层section合并
            HStack(spacing: 8) {
                Text("\(state.statsRange == 0 ? "近7天" : "近30天") · 每日水合")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                chartKindSegment
            }
            // 三行定高 值12+轨100+标签14 柱状折线共用 目标虚线钉在轨行内
            chartBody(stats, top: Double(top))
            barTip(stats)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    // 卡头迷你分段 图标版 HealthTick卡头右侧切换同款
    var chartKindSegment: some View {
        HStack(spacing: 2) {
            ForEach(Self.chartKinds.indices, id: \.self) { i in
                Button {
                    state.statsChartKind = i
                } label: {
                    Image(systemName: Self.chartKinds[i].icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(state.statsChartKind == i ? Color.owAccent : Color.primary.opacity(0.55))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            state.statsChartKind == i
                                ? AnyShapeStyle(Color.primary.opacity(0.14))
                                : AnyShapeStyle(Color.clear),
                            in: RoundedRectangle(cornerRadius: 5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(Self.chartKinds[i].name)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
    }

    // 三种形态 图标+悬停名称提示
    static let chartKinds: [(icon: String, name: String)] = [
        ("drop.fill", "水滴"),
        ("chart.bar.fill", "柱状"),
        ("chart.xyaxis.line", "折线"),
    ]

    // 图区三行 值/轨/标签 柱状与折线共用 整列热区overlay
    func chartBody(_ stats: [DayStat], top: Double) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(stats.indices, id: \.self) { i in
                    Text((state.statsRange == 0 || state.statsHoverBar == i) && stats[i].ml > 0 ? "\(stats[i].ml)" : "")
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .foregroundColor(state.statsHoverBar == i ? Color.owAccent : .secondary)
                        .frame(height: 12)
                        .frame(maxWidth: .infinity)
                }
            }
            chartTrack(stats, top: top)
                .frame(height: 100)
            HStack(spacing: 0) {
                ForEach(stats.indices, id: \.self) { i in
                    Text(barLabel(i, stats[i]))
                        .font(.system(size: 9))
                        .foregroundColor(state.statsHoverBar == i ? .primary : .secondary)
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .overlay(
            HStack(spacing: 0) {
                ForEach(stats.indices, id: \.self) { i in
                    Color.clear
                        .contentShape(Rectangle())
                        .onHover { on in
                            state.statsHoverBar = on ? i : (state.statsHoverBar == i ? nil : state.statsHoverBar)
                        }
                }
            })
    }

    // 轨行按形态分叉
    @ViewBuilder
    func chartTrack(_ stats: [DayStat], top: Double) -> some View {
        if state.statsChartKind == 0 {
            dropTrack(stats)
        } else if state.statsChartKind == 1 {
            barTrack(stats, top: top)
        } else {
            lineTrack(stats, top: top)
        }
    }

    // 柱状轨 零天贴底基线小条 hover整列淡高亮
    func barTrack(_ stats: [DayStat], top: Double) -> some View {
        return HStack(spacing: 0) {
            ForEach(stats.indices, id: \.self) { i in
                let s = stats[i]
                let hovered = state.statsHoverBar == i
                ZStack {
                    if hovered {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.03))
                    }
                    VStack {
                        Spacer(minLength: 0)
                        if s.ml > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(s.met ? Color.owAccent : Color.owAccent.opacity(0.4))
                                .frame(width: 36, height: max(3, 100 * Double(s.ml) / top))
                        } else {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.primary.opacity(0.2))
                                .frame(width: 18, height: 3)
                                .padding(.bottom, 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // 折线轨 平滑点线+面积渐变 悬停点放大
    func lineTrack(_ stats: [DayStat], top: Double) -> some View {
        return GeometryReader { g in
            let n = max(1, stats.count)
            let cw = g.size.width / CGFloat(n)
            let pts: [CGPoint] = stats.indices.map { i in
                CGPoint(x: cw * (CGFloat(i) + 0.5),
                        y: 100 - 100 * Double(stats[i].ml) / top)
            }
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: pts[0].x, y: 100))
                    pts.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: pts[n - 1].x, y: 100))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color.owAccent.opacity(0.22), Color.owAccent.opacity(0.02)],
                                     startPoint: .top, endPoint: .bottom))
                Path { p in
                    pts.enumerated().forEach { i, pt in
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(Color.owAccent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                ForEach(stats.indices, id: \.self) { i in
                    Circle()
                        .fill(state.statsHoverBar == i ? Color.owAccent : Color.primary.opacity(0.4))
                        .frame(width: state.statsHoverBar == i ? 7 : 4,
                               height: state.statsHoverBar == i ? 7 : 4)
                        .position(pts[i])
                }
            }
        }
    }

    // 水滴轨 一天一滴 越多越深 按当天量/目标比值分档 0记录空心浅灰
    func dropTrack(_ stats: [DayStat]) -> some View {
        HStack(spacing: 0) {
            ForEach(stats.indices, id: \.self) { i in
                let s = stats[i]
                let hovered = state.statsHoverBar == i
                ZStack {
                    if hovered {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.03))
                    }
                    VStack {
                        Spacer(minLength: 0)
                        Image(systemName: s.ml == 0 ? "drop" : "drop.fill")
                            .font(.system(size: stats.count <= 7 ? 38 : 18))
                            .foregroundColor(s.ml == 0
                                ? Color.secondary.opacity(0.45)
                                : Color.owAccent.opacity(dropLevel(s)))
                            .scaleEffect(hovered ? 1.12 : 1)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovered)
                    }
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // 深=越接近/超过当天目标
    func dropLevel(_ s: DayStat) -> Double {
        let r = Double(s.ml) / Double(max(1, s.goal))
        return r >= 1 ? 1.0 : r >= 0.66 ? 0.75 : r >= 0.33 ? 0.5 : 0.28
    }

    // 底部标签 近7天=日期(M/d) 30天每5天标日期号 末位必标
    func barLabel(_ idx: Int, _ s: DayStat) -> String {
        if state.statsRange == 0 {
            return Self.mdShortFormat.string(from: Self.date(s.date))
        }
        let day = Calendar.current.component(.day, from: Self.date(s.date))
        return idx % 5 == 0 || idx == 29 ? "\(day)" : ""
    }

    @ViewBuilder
    func barTip(_ stats: [DayStat]) -> some View {
        let tip: String
        if let h = state.statsHoverBar, stats.indices.contains(h) {
            let s = stats[h]
            tip = "\(Self.mdFormat.string(from: Self.date(s.date))) · \(s.ml.formatted()) ml · \(s.cups) 杯 · 目标 \(s.goal.formatted())\(s.met ? " · 已达标" : "")"
        } else {
            tip = ""   // 未悬停留空占位 防悬停时布局跳动
        }
        return Text(tip)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
    }

    // MARK: 饮品构成 WaterMinder式 横条+emoji+占比

    func typeCard(_ dates: [String]) -> some View {
        let totals = db.typeTotals(dates: dates)
        let rawSum = max(1, totals.reduce(0) { $0 + $1.ml })
        return VStack(alignment: .leading, spacing: 6) {
            if totals.isEmpty {
                Text("所选范围还没有记录")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(totals.indices, id: \.self) { i in
                    let t = totals[i]
                    HStack(spacing: 8) {
                        Image(systemName: t.type.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(t.type.tint)
                            .frame(width: 18)
                        Text(t.type.name)
                            .font(.system(size: 11))
                            .foregroundColor(t.type.tint)
                            .frame(width: 30, alignment: .leading)
                        GeometryReader { g in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(t.type.tint)
                                .frame(width: max(4, g.size.width * Double(t.ml) / Double(rawSum)),
                                       height: 8)
                                .frame(height: g.size.height, alignment: .center)
                        }
                        Text("\(t.ml) ml · \(t.cups) 杯")
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 96, alignment: .trailing)
                    }
                    .frame(height: 18)
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    // 底部激励文案 HealthTick式
    var footerLine: some View {
        let goal = db.todayGoalOverride() ?? config.dailyGoalML
        let total = db.todayTotalML()
        let met = goal > 0 && total >= goal
        return Text(met ? "今日已达标 保持住 💧"
                    : total > 0 ? "今日还差 \(goal - total) ml 来一杯"
                    : "今天还没记录 从一杯开始")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(met ? Color.owAccent : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }

    // 卡片小灰标题 同设置页
    func sectionHeader(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
            .padding(.bottom, -4)
    }
}
