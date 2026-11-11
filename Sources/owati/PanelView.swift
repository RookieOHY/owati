import SwiftUI

// 最近一次可撤销的操作
enum UndoAction {
    case deleted(id: Int64, date: Date, ml: Int)  // 删除 按原时间插回
    case edited(id: Int64, oldML: Int)            // 修改 回退到旧值
}

// 面板交互状态
final class PanelState: ObservableObject {
    static let shared = PanelState()
    @Published var unitIndex = 0          // 剩余 0 ml 1 L 2 升
    @Published var showCountdown = false  // 下次提醒 时刻 <-> 倒计时
    @Published var hoverDay: Int? = nil   // 周水滴悬停的列序号
    @Published var hoverConfirmed: Int? = nil // 过了延迟还悬停才亮tooltip 挡布局跳变时的瞬时误报
    private var hoverWork: DispatchWorkItem?

    // 悬停防抖 0.25秒后才真正亮提示
    func setHover(_ idx: Int?) {
        hoverWork?.cancel()
        hoverWork = nil
        hoverDay = idx
        if idx == nil {
            hoverConfirmed = nil
            return
        }
        let w = DispatchWorkItem { [weak self] in
            self?.hoverConfirmed = self?.hoverDay
        }
        hoverWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: w)
    }
    @Published var showDetail = false     // 今日详情 展开/收起
    @Published var dateMode = 0          // 右上角 0公历 1农历 2周五判断 点击循环
    @Published var showLab = false       // 实验室页 面板左滑进入
    @Published var celebrate = false      // 达标庆祝 一次性
    var wasGoalReached = false            // 上次是否已达标 算跨越用

    // 波浪相位累加器 逐帧推进 庆祝时加速
    final class WaveClock {
        var phase: Double = 0
        var last: Date?
    }
    let waveClock = WaveClock()

    // 波浪相位推进 逐帧调用 庆祝时奔腾
    func advanceWave(now: Date, celebrate: Bool) -> Double {
        let clock = waveClock
        let dt = clock.last.map { now.timeIntervalSince($0) } ?? 0
        clock.last = now
        clock.phase += dt * (celebrate ? 7.5 : 2.2)
        return clock.phase
    }

    // 每秒检查是否刚跨过目标 跨过就放一次庆祝
    func checkGoal(consumedML: Double, goal: Int) {
        let reached = goal > 0 && consumedML >= Double(goal)
        if reached && !wasGoalReached {
            celebrate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
                self?.celebrate = false
            }
        }
        wasGoalReached = reached
    }
    @Published var hoverRow: Int64? = nil // 时间线悬停的记录id
    @Published var editingId: Int64? = nil    // 正在改ml的记录id
    @Published var editingText = ""           // 编辑框当前内容
    var editingOldML = 0                      // 进编辑前的量 算撤销用
    @Published var undo: UndoAction? = nil    // 最近一次可撤销操作
    @Published var undoText = ""
    @Published var panelHeight: CGFloat = 0   // 内容实测高度 用于同步窗口
    var pageHeight: CGFloat = 0               // 主页滑动区高度 实验室页钉这个高度 滑动期间窗口不变
    // 假数据 下次提醒按启动时间+间隔算 之后由提醒器接管
    let nextRemind = Date().addingTimeInterval(45 * 60)

    private var undoToken = 0
    private var undoWork: DispatchWorkItem?

    // 记一笔可撤销操作 6秒没撤销就过期
    func setUndo(_ a: UndoAction, text: String) {
        undo = a
        undoText = text
        undoToken += 1
        let token = undoToken
        undoWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            if self?.undoToken == token {
                self?.undo = nil
                self?.undoText = ""
            }
        }
        undoWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: w)
    }

    // 清掉撤销(撤销成功或新操作顶掉时)
    func clearUndo() {
        undoWork?.cancel()
        undo = nil
        undoText = ""
    }
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

    // 农历换算 系统自带chinese历法 零依赖
    static let lunarCal = Calendar(identifier: .chinese)
    static let lunarMonths = ["正月", "二月", "三月", "四月", "五月", "六月",
                              "七月", "八月", "九月", "十月", "冬月", "腊月"]
    static let lunarDays = ["初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
    static func lunarText(_ date: Date) -> String {
        let c = lunarCal.dateComponents([.month, .day], from: date)
        guard let m = c.month, let d = c.day,
              m >= 1, m <= 12, d >= 1, d <= 30 else { return "" }
        return "\(c.isLeapMonth == true ? "闰" : "")\(lunarMonths[m - 1])\(lunarDays[d - 1])"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in // 秒级时钟 驱动日期和倒计时
            let _ = state.checkGoal(consumedML: consumedML, goal: config.dailyGoalML)
            VStack(spacing: 0) {
                // 滑动区 主页 <-> 实验室页
                ZStack {
                    // 主页
                    VStack(spacing: 16) {
                        // 左上角 今天 + 日期注脚
                        HStack(alignment: .firstTextBaseline) {
                            Text("今日")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            topRightDate(ctx.date)
                        }
                        // 圆环 + 环下三列数据
                        VStack(spacing: 12) {
                            WaveRing(progress: consumedML / Double(config.dailyGoalML),
                                     consumedML: consumedML, goalML: config.dailyGoalML,
                                     celebrate: state.celebrate)
                            // 三列数据
                            HStack(spacing: 0) {
                                statCol("\(db.todayCups()) 杯", "杯数")
                                statCol("\(db.streakDays(goalML: config.dailyGoalML)) 天", "连续")
                                statCol(db.lastDrinkText() ?? "—", "距上次")
                            }
                            statusLine
                            weekDrops
                            todayDetail
                        }
                        // 两张卡
                        HStack(spacing: 10) {
                            remainCard
                            remindCard(ctx.date)
                        }
                        // 撤销条 有可撤销操作时出现
                        if state.undo != nil {
                            undoBar
                                .transition(.opacity)
                        }
                    }
                    // 进实验室时主页淡出并禁点 空白页才有"翻页"感
                    .opacity(state.showLab ? 0 : 1)
                    .allowsHitTesting(!state.showLab)
                    // 实验室页 从右滑入(内容向左) 高度钉在主页高度 滑动期间窗口不变
                    if state.showLab {
                        labPage
                            .frame(height: state.pageHeight > 0 ? state.pageHeight : nil, alignment: .top)
                            .transition(.move(edge: .trailing))
                    }
                }
                .background(
                    GeometryReader { g in
                        Color.clear
                            .onAppear { if !state.showLab { state.pageHeight = g.size.height } }
                            .onChange(of: g.size.height) { if !state.showLab { state.pageHeight = $0 } }
                    }
                )
                // 底部 分隔线 + 按钮排 常驻不参与滑动
                VStack(spacing: 14) {
                    Divider().padding(.horizontal, 4)
                    HStack(spacing: 0) {
                        controlButton("统计", "chart.xyaxis.line", "1") { /* 统计页后续做 */ }
                        controlButton("成就", "trophy", "2") { /* 成就页后续做 */ }
                        controlButton("帮助", "questionmark.circle", "3") { /* 帮助页后续做 */ }
                        controlButton("实验室", "wand.and.stars", "4", active: state.showLab) {
                            state.setHover(nil)
                            state.hoverRow = nil
                            withAnimation(.easeOut(duration: 0.25)) { state.showLab.toggle() }
                        }
                        controlButton("设置", "gear", "5") { OwatiApp.showOnboarding() }
                        controlButton("退出", "power", "q") { NSApp.terminate(nil) }
                    }
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 14)
        }
        // 宽度固定 高度随内容自动撑 定高会在内容变化时把上下裁掉
        .frame(width: 240)
        // 实测内容高度 变化时同步宿主窗口(MenuBarExtra只会撑大不会自己缩)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { state.panelHeight = geo.size.height }
                    .onChange(of: geo.size.height) { state.panelHeight = $0 }
            }
        )
        // 钉在窗口顶部 高度跳变时内容不整体位移 不会从光标底下扫出悬停
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: state.panelHeight) { _ in syncWindowHeight() }
    }

    // 内容高度变了 把宿主窗口改成一样高 顶边贴着菜单栏不动
    func syncWindowHeight() {
        let h = state.panelHeight
        guard h > 0 else { return }
        for w in NSApp.windows {
            if w.styleMask.contains(.titled) || w.frame.height <= 80 || w.frame.width > 400 { continue }
            var f = w.frame
            let topY = f.origin.y + f.height
            guard abs(f.height - h) > 0.5 else { continue }
            // 立即到位 不动画 动画才会和内容节奏错开露出空白
            f.size.height = h
            f.origin.y = topY - h
            w.setFrame(f, display: true)
            // 窗口一跳 视图会在光标底下扫过 主动清悬停防tooltip闪现/卡住
            state.setHover(nil)
            state.hoverRow = nil
        }
    }

    // 底栏按钮 图标+小字 active时点亮主题色
    func controlButton(_ title: String, _ icon: String, _ key: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(.system(size: 9))
            }
            .frame(width: 36, height: 32)
            .foregroundColor(active ? Color.accentColor : Color.primary.opacity(0.5))
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

    // 右上角 点击循环 公历 -> 农历 -> 周五判断
    func topRightDate(_ date: Date) -> some View {
        Group {
            switch state.dateMode {
            case 1:
                Text(Self.lunarText(date))
            case 2:
                let isFriday = true // 临时写死预览周五形态 看完改回
                if isFriday {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("今天是 ")
                                .font(.system(size: 11))
                            Text("周五")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                        // 重点线 压在周五正下方
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 20, height: 2)
                            .offset(x: -5)
                    }
                } else {
                    Text("今天不是周五")
                        .font(.system(size: 11))
                }
            default:
                Text(Self.dayFormat.string(from: date))
                    .font(.system(size: 11))
            }
        }
        .foregroundColor(.secondary)
        .contentShape(Rectangle())
        .onTapGesture { state.dateMode = (state.dateMode + 1) % 3 }
    }

    // 周五彩蛋 到了周五右上角会喊出来 周五俩字加大
    func fridayText(_ date: Date) -> some View {
        let isFriday = Calendar.current.component(.weekday, from: date) == 6
        return Group {
            if isFriday {
                (Text("今天是 ")
                    + Text("周五").font(.system(size: 14, weight: .semibold)))
                    .font(.system(size: 11))
            } else {
                Text("今天不是周五")
                    .font(.system(size: 11))
            }
        }
        .foregroundColor(.secondary)
    }

    // 本周水滴 一天一滴 滴内是当天杯数 滴下是几号 周一开头 悬停显示当天详情
    var weekDrops: some View {
        let cal = Calendar(identifier: .iso8601) // 周一为一周开始
        let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())!.start
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        let counts = db.cupsByDate(dates: days.map { Database.dayFormat.string(from: $0) })
        let totals = db.mlByDate(dates: days.map { Database.dayFormat.string(from: $0) })
        return HStack(spacing: 5) {
            ForEach(Array(days.enumerated()), id: \.offset) { pair in
                let idx = pair.offset
                let d = pair.element
                let isToday = cal.isDateInToday(d)
                let n = counts[Database.dayFormat.string(from: d), default: 0]
                let ml = totals[Database.dayFormat.string(from: d), default: 0]
                VStack(spacing: 4) {
                    ZStack {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(isToday ? AnyShapeStyle(Color.accentColor)
                                                      : AnyShapeStyle(Color.primary.opacity(0.12)))
                        if n > 0 {
                            Text("\(n)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(isToday ? .white : .primary.opacity(0.6))
                                .offset(y: 1.5)
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
                .onHover { hovering in
                    state.setHover(hovering ? idx : nil)
                }
                // 悬停小卡 浮在滴上方 靠边两列向内收 防探出面板
                .overlay(alignment: .top) {
                    if state.hoverConfirmed == idx {
                        VStack(spacing: 2) {
                            Text(Self.dayFormat.string(from: d))
                                .fontWeight(.medium)
                            Text(n > 0 ? "\(ml) ml · \(n) 杯" : "没有记录")
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 10))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.primary.opacity(0.1)))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .fixedSize()
                        .offset(x: idx == 0 ? 14 : (idx == 6 ? -14 : 0), y: -40)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)))
                        .zIndex(10)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: state.hoverConfirmed)
    }

    // 间隔标注 轨道在这里断成虚线 文字贴着断口 表达这段没喝水
    func gapMarker(_ minutes: Int) -> some View {
        let h = Int((Double(minutes) / 60).rounded())
        return HStack(spacing: 8) {
            Color.clear.frame(width: 32, height: 0)
            Rectangle()
                .stroke(Color.primary.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .frame(width: 1, height: 14)
            Text("隔了 \(h) 小时")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .padding(.vertical, 1)
    }

    // 今日详情 开关行 + 喝水时间线 时间正序
    var todayDetail: some View {
        let records = db.todayRecords()
        // 间隔标注条数 高度计算用
        let gapMarks = zip(records, records.dropFirst())
            .filter { $1.date.timeIntervalSince($0.date) >= 7200 }.count
        return VStack(spacing: 6) {
            Button {
                state.showDetail.toggle()
                // 布局要跳变 清掉悬停 免得水滴tooltip在光标下被扫出来
                state.setHover(nil)
                state.hoverRow = nil
            } label: {
                HStack {
                    Text("今日详情")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    // 胶囊小开关 朝下=展开 朝上=收起
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(state.showDetail ? 180 : 0))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.primary.opacity(0.07), in: Capsule())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // 不加动画 内容和窗口同一帧跳变 才不会有中间态空白
            if state.showDetail {
                if records.isEmpty {
                    Text("今天还没有记录")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                } else {
                    // 竖轨串起每一条 时间左 量右 悬停可删 可改ml
                    // 每行20pt(16内容+4上下距) 少时贴内容 多时3行封顶滚动
                    ScrollView {
                        VStack(spacing: 0) {
                        ForEach(Array(records.enumerated()), id: \.element.id) { i, r in
                            // 隔太久插一条间隔标注
                            if i > 0 {
                                let gapMin = Int(r.date.timeIntervalSince(records[i - 1].date) / 60)
                                if gapMin >= 120 {
                                    gapMarker(gapMin)
                                }
                            }
                            HStack(spacing: 8) {
                                Text(Self.timeFormat.string(from: r.date))
                                    .font(.system(size: 10))
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, alignment: .leading)
                                ZStack {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.12))
                                        .frame(width: 1)
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 5, height: 5)
                                }
                                .frame(height: 16)
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color.accentColor.opacity(0.55))
                                Spacer()
                                // 量 点击进编辑 回车保存 Esc取消
                                if state.editingId == r.id {
                                    TextField("", text: Binding(
                                        get: { state.editingText },
                                        set: { state.editingText = $0 }
                                    ))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11, weight: .semibold))
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 42)
                                    .onSubmit { commitEdit() }
                                    .onExitCommand { state.editingId = nil }
                                } else {
                                    Text("\(r.ml) ml")
                                        .font(.system(size: 11, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundColor(.primary)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            state.editingId = r.id
                                            state.editingText = "\(r.ml)"
                                            state.editingOldML = r.ml
                                        }
                                }
                                // 删除按钮 悬停该行才出现 占位不跳动
                                ZStack {
                                    if state.hoverRow == r.id {
                                        Button {
                                            state.setUndo(.deleted(id: r.id, date: r.date, ml: r.ml),
                                                          text: "已删除 \(r.ml) ml")
                                            db.deleteDrink(id: r.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 8, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .frame(width: 14, height: 14)
                                                .background(.primary.opacity(0.1), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(width: 15)
                            }
                            .padding(.vertical, 2)
                            .onHover { hovering in
                                state.hoverRow = hovering ? r.id : (state.hoverRow == r.id ? nil : state.hoverRow)
                            }
                        }
                        }
                    }
                    // 确定性高度 行20pt 标注16pt 超了封顶滚动
                    .frame(height: min(CGFloat(records.count) * 20 + CGFloat(gapMarks) * 16 + 2, 62))
                    .padding(.top, 2)
                }
            }
        }
    }

    // 撤销条 最近一次删除/修改可反悔
    var undoBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.uturn.backward.circle")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(state.undoText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Button {
                performUndo()
            } label: {
                Text("撤销")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // 执行撤销
    func performUndo() {
        guard let u = state.undo else { return }
        switch u {
        case .deleted(_, let date, let ml):
            db.restoreDrink(ts: date, ml: ml)
        case .edited(let id, let oldML):
            db.updateDrink(id: id, ml: oldML)
        }
        state.clearUndo()
    }

    // 保存编辑的ml 非法输入直接退出编辑
    func commitEdit() {
        defer {
            state.editingId = nil
            state.editingText = ""
        }
        guard let id = state.editingId, let ml = Int(state.editingText.trimmingCharacters(in: .whitespaces)) else { return }
        guard ml > 0, ml <= 5000 else { return }
        guard ml != state.editingOldML else { return }
        db.updateDrink(id: id, ml: ml)
        state.setUndo(.edited(id: id, oldML: state.editingOldML), text: "已改为 \(ml) ml")
    }

    // 实验室页 左滑进入 空白面板 再点实验室按钮滑回
    var labPage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
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
    var celebrate: Bool = false

    // 空态也留一点水位 "还没喝"也有画面
    private var waterLevel: Double { max(progress, 0.06) }
    private var isEmpty: Bool { progress <= 0.001 }

    var body: some View {
        ZStack {
            // 圆内底色 亮暗外观都衬文字
            Circle().fill(.primary.opacity(0.05))
            // 外圈进度弧
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.08), style: StrokeStyle(lineWidth: 6))
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [.cyan, .blue, .indigo], center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360 * progress)),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90)) // 从正上方起笔
                // 顶部高光 玻璃感
                Circle()
                    .trim(from: 0.01, to: 0.24)
                    .stroke(
                        AngularGradient(colors: [.white.opacity(0.02), .white.opacity(0.3), .white.opacity(0.02)],
                                        center: .center, startAngle: .degrees(-80), endAngle: .degrees(-20)),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
            }
            .padding(3)
            // 波浪 双层 一深一浅错开动 相位累加 庆祝时奔腾
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                let p = PanelState.shared.advanceWave(now: ctx.date, celebrate: celebrate)
                ZStack {
                    WaveShape(level: waterLevel, phase: p + 1.3, amplitude: 4)
                        .fill(.cyan.opacity(0.3))
                    WaveShape(level: waterLevel, phase: p * 1.41 + 3.8, amplitude: 5.5)
                        .fill(LinearGradient(colors: [.blue.opacity(0.7), .cyan.opacity(0.85)],
                                             startPoint: .top, endPoint: .bottom))
                }
                .animation(.spring(duration: 0.9, bounce: 0.25), value: progress)
            }
            .clipShape(Circle())
            .padding(6)
            // 中央 百分比 + 喝了多少 空态数字弱化
            VStack(spacing: 3) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundColor(isEmpty ? .primary.opacity(0.35) : .primary)
                    .scaleEffect(celebrate ? 1.12 : 1)
                    .animation(.spring(duration: 0.45, bounce: 0.5), value: celebrate)
                Text("\(Int(consumedML)) / \(goalML) ml")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .opacity(0.7)
            }
        }
        .frame(width: 120, height: 120)
        // 达标微弹 整环轻弹一下
        .scaleEffect(celebrate ? 1.05 : 1)
        .animation(.spring(duration: 0.45, bounce: 0.45), value: celebrate)
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
