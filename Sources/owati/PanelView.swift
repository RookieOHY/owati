import SwiftUI

// 面板主体 主页 + 底栏 + 窗口高度同步
struct PanelView: View {
    @ObservedObject var state = PanelState.shared
    @ObservedObject var config = AppConfig.shared
    let db = Database.shared

    // 今日已喝 真数据 来自SQLite
    var consumedML: Double { Double(db.todayTotalML()) }

    // 今日生效目标 当日覆盖优先 否则用全局默认
    var todayGoal: Int { db.todayGoalOverride() ?? config.dailyGoalML }

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

    // 产品logo 与状态栏同源 模板模式可染色
    static let productLogo: NSImage? = {
        let path = (#filePath as NSString).deletingLastPathComponent + "/../../demo/png/owati-44.png"
        guard let img = NSImage(contentsOfFile: path) else { return nil }
        img.size = NSSize(width: 28, height: 28)
        img.isTemplate = true
        return img
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in // 秒级时钟 驱动日期和倒计时
            let _ = state.checkGoal(consumedML: consumedML, goal: todayGoal)
            VStack(spacing: 0) {
                // 滑动区 主页 <-> 实验室页
                ZStack {
                    // 主页
                    VStack(spacing: 16) {
                        // 左上角 logo呼吸灯 + 日期注脚
                        HStack(alignment: .center, spacing: 8) {
                            logoBreath
                            Spacer()
                            topRightDate(ctx.date)
                        }
                        // 圆环 + 环下三列数据
                        VStack(spacing: 12) {
                            WaveRing(progress: consumedML / Double(todayGoal),
                                     consumedML: consumedML, goalML: todayGoal,
                                     celebrate: state.celebrate)
                                .contentShape(Circle())
                                .onTapGesture { logDrink(config.cupML) }
                            // 快捷记录 三等分通栏 图标+毫升数
                            HStack(spacing: 8) {
                                presetButton("mug.fill", "一杯", config.cupML, id: "杯")
                                presetButton("takeoutbag.and.cup.and.straw.fill", "一瓶", config.bottleML, id: "瓶")
                                presetButton("plus.circle", "自定义", nil, id: "自定义")
                            }
                            // 自定义量记录输入行 点"自定义"展开
                            if state.editingCustom {
                                customDrinkRow
                            }
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
                        controlButton("设置", "gear", "5") {
                            state.setHover(nil)
                            state.hoverRow = nil
                            // HealthTick式 先收面板再弹设置窗 面板挡不住视线
                            for w in NSApp.windows
                            where !w.styleMask.contains(.titled) && w.frame.width <= 400 && w.frame.height > 80 {
                                w.orderOut(nil)
                            }
                            SettingsWindow.show()
                        }
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
        // 面板一收起(失key) 今日详情恢复折叠 下次打开从干净状态开始
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            guard let w = note.object as? NSWindow,
                  !w.styleMask.contains(.titled), w.frame.height > 80, w.frame.width <= 400 else { return }
            state.showDetail = false
            state.editingCustom = false   // 自定义行同样收起 输入清空
            state.customText = ""
            state.editingId = nil   // 行内ml编辑取消
            state.editingText = ""
        }
    }

    // 圆角矩形轮廓 从顶部中央起笔顺时针 point(in:t:) 按周长等比取点 供刻度/动点定位
    struct RoundedRectOutlineShape: Shape {
        var radius: CGFloat

        nonisolated func path(in rect: CGRect) -> Path {
            Self.path(in: rect, radius: radius)
        }

        static func path(in rect: CGRect, radius: CGFloat) -> Path {
            let r = min(radius, rect.width / 2, rect.height / 2)
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                     startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                     startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                     startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                     startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            return p
        }

        // 圆角矩形部分路径 与 point() 同一套数学 from/to按周长等比
        struct RoundedRectPartialShape: Shape {
            var from: Double
            var to: Double
            var radius: CGFloat

            nonisolated var animatableData: AnimatablePair<Double, Double> {
                get { AnimatablePair(from, to) }
                set { from = newValue.first; to = newValue.second }
            }

            nonisolated func path(in rect: CGRect) -> Path {
                let r = min(radius, rect.width / 2, rect.height / 2)
                let topHalf = Double((rect.maxX - r) - rect.midX)
                let arcLen = Double.pi * Double(r) / 2
                let rightEdge = Double((rect.maxY - r) - (rect.minY + r))
                let bottomEdge = Double((rect.maxX - r) - (rect.minX + r))
                // 周长=顶半×2+四弧+右边×2+下边 之前下边多算一遍 高进度会提前画满
                let perimeter = 2 * topHalf + 4 * arcLen + 2 * rightEdge + bottomEdge
                let d0 = max(0, min(from, 1)) * perimeter
                let d1 = max(0, min(to, 1)) * perimeter
                var p = Path()
                guard d1 > d0 else { return p }
                var first = true
                func at(_ d: Double) -> CGPoint { RoundedRectOutlineShape.point(in: rect, t: d / perimeter, radius: r) }
                func moveTo(_ d: Double) {
                    if first { p.move(to: at(d)); first = false }
                }
                func arc(_ center: CGPoint, _ deg0: Double, _ deg1: Double) {
                    p.addArc(center: center, radius: r,
                             startAngle: .degrees(deg0), endAngle: .degrees(deg1), clockwise: false)
                }
                var a = 0.0
                var ov = min(d1, a + topHalf) - max(d0, a)
                if ov > 0 { moveTo(max(d0, a)); p.addLine(to: at(min(d1, a + topHalf))) }
                a += topHalf
                let trC = CGPoint(x: rect.maxX - CGFloat(r), y: rect.minY + CGFloat(r))
                ov = min(d1, a + arcLen) - max(d0, a)
                if ov > 0 { moveTo(max(d0, a)); arc(trC, -90 + (max(d0, a) - a) / arcLen * 90, -90 + (min(d1, a + arcLen) - a) / arcLen * 90) }
                a += arcLen
                ov = min(d1, a + rightEdge) - max(d0, a)
                if ov > 0 { moveTo(max(d0, a)); p.addLine(to: at(min(d1, a + rightEdge))) }
                a += rightEdge
                let brC = CGPoint(x: rect.maxX - CGFloat(r), y: rect.maxY - CGFloat(r))
                ov = min(d1, a + arcLen) - max(d0, a)
                if ov > 0 { moveTo(max(d0, a)); arc(brC, (max(d0, a) - a) / arcLen * 90, (min(d1, a + arcLen) - a) / arcLen * 90) }
                a += arcLen
                ov = min(d1, a + bottomEdge) - max(d0, a)
                if ov > 0 { moveTo(max(d0, a)); p.addLine(to: at(min(d1, a + bottomEdge))) }
                a += bottomEdge
                let blC = CGPoint(x: rect.minX + CGFloat(r), y: rect.maxY - CGFloat(r))
                ov = min(d1, a + arcLen) - max(d0, a)
                if ov > 0 { moveTo(max(d0, a)); arc(blC, 90 + (max(d0, a) - a) / arcLen * 90, 90 + (min(d1, a + arcLen) - a) / arcLen * 90) }
                a += arcLen
                ov = min(d1, a + rightEdge) - max(d0, a)
                if ov > 0 { moveTo(max(d0, a)); p.addLine(to: at(min(d1, a + rightEdge))) }
                a += rightEdge
                let tlC = CGPoint(x: rect.minX + CGFloat(r), y: rect.minY + CGFloat(r))
                ov = min(d1, a + arcLen) - max(d0, a)
                if ov > 0 { moveTo(max(d0, a)); arc(tlC, 180 + (max(d0, a) - a) / arcLen * 90, 180 + (min(d1, a + arcLen) - a) / arcLen * 90) }
                a += arcLen
                ov = min(d1, a + topHalf) - max(d0, a)
                if ov > 0 { moveTo(max(d0, a)); p.addLine(to: at(min(d1, a + topHalf))) }
                return p
            }
        }

        // 周长等比取点 t∈[0,1] 与 trim 的起点对齐
        static func point(in rect: CGRect, t: Double, radius: CGFloat) -> CGPoint {
            let r = min(radius, rect.width / 2, rect.height / 2)
            let topHalf = (rect.maxX - r) - rect.midX
            let arc = .pi * r / 2
            let rightEdge = (rect.maxY - r) - (rect.minY + r)
            let bottomEdge = (rect.maxX - r) - (rect.minX + r)
            // 周长=顶半×2+四弧+右边×2+下边 下边只走一遍 与 PartialShape 保持一致
            let perimeter = 2 * topHalf + 4 * arc + 2 * rightEdge + bottomEdge
            var d = max(0, min(t, 1)) * perimeter
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { .init(x: x, y: y) }
            func arcPt(_ cx: CGFloat, _ cy: CGFloat, _ deg: Double) -> CGPoint {
                pt(cx + r * CGFloat(cos(deg * .pi / 180)), cy + r * CGFloat(sin(deg * .pi / 180)))
            }
            if d <= topHalf { return pt(rect.midX + CGFloat(d), rect.minY) }
            d -= topHalf
            if d <= arc { return arcPt(rect.maxX - r, rect.minY + r, -90 + d / arc * 90) }
            d -= arc
            if d <= rightEdge { return pt(rect.maxX, rect.minY + r + CGFloat(d)) }
            d -= rightEdge
            if d <= arc { return arcPt(rect.maxX - r, rect.maxY - r, d / arc * 90) }
            d -= arc
            if d <= bottomEdge { return pt(rect.maxX - r - CGFloat(d), rect.maxY) }
            d -= bottomEdge
            if d <= arc { return arcPt(rect.minX + r, rect.maxY - r, 90 + d / arc * 90) }
            d -= arc
            if d <= rightEdge { return pt(rect.minX, rect.maxY - r - CGFloat(d)) }
            d -= rightEdge
            if d <= arc { return arcPt(rect.minX + r, rect.minY + r, 180 + d / arc * 90) }
            d -= arc
            return pt(rect.minX + r + CGFloat(d), rect.minY)
        }
    }

    // 分享按钮 右上角 打开今日成就卡片弹窗
    var shareBtn: some View {
        Button {
            ShareCardWindow.show()
        } label: {
            Image(systemName: "arrowshape.turn.up.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(state.hoverBtn == "分享" ? Color.accentColor : Color.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            state.hoverBtn = h ? "分享" : (state.hoverBtn == "分享" ? nil : state.hoverBtn)
        }
    }

    // 产品logo 呼吸灯 无色→蓝→无色 5秒一周期 MacBook呼吸灯同款节奏
    // 双层叠加: 底层常驻原色 顶层蓝色随呼吸盖上 颜色是真插值不是透明度闪
    var logoBreath: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let s = 0.5 + 0.5 * sin(ctx.date.timeIntervalSinceReferenceDate * 2 * .pi / 5.0)
            ZStack {
                if let logo = Self.productLogo {
                    Image(nsImage: logo).foregroundColor(.primary)
                    Image(nsImage: logo).foregroundColor(.accentColor.opacity(s))
                } else {
                    Image(systemName: "drop.fill").font(.system(size: 28)).foregroundColor(.primary)
                    Image(systemName: "drop.fill").font(.system(size: 28)).foregroundColor(.accentColor.opacity(s))
                }
            }
            // 峰值辉光 + 微缩放
            .shadow(color: .accentColor.opacity(0.5 * s), radius: 5)
            .scaleEffect(1 + 0.05 * s)
        }
    }

    // 记一笔 唯一入口 面板立即刷新 误点可撤销
    func logDrink(_ ml: Int, type: DrinkType = .water) {
        let id = db.addDrink(ml, type: type)
        guard id != 0 else { return }
        SoundPlayer.shared.playLog()   // 记录成功才有声音
        state.markLogged()   // 刚喝过水 提醒重新计时
        state.drinkPulse += 1
        // 撤销条显示水合换算后的值 和环进度同一口径
        let hydrated = Int((Double(ml) * type.ratio).rounded())
        let name = type == .water ? "" : "\(type.name) "
        state.setUndo(.added(id: id), text: "已记录 \(name)\(hydrated) ml")
    }

    // 补记 指定分钟前 同样可撤销（暂无入口 备用）
    func logBack(_ minutes: Int, _ ml: Int) {
        let ts = Date().addingTimeInterval(Double(-minutes) * 60)
        let id = db.restoreDrink(ts: ts, ml: ml)
        guard id != 0 else { return }
        state.drinkPulse += 1
        state.setUndo(.added(id: id), text: "已补记 \(ml) ml")
    }

    // 自定义量记录行 单行 类型循环切换+输入框+系数+换算+记下
    var customDrinkRow: some View {
        HStack(spacing: 5) {
            // 类型选择器 单击循环切换 水→咖啡→茶→牛奶→果汁→水
            Button {
                let all = DrinkType.allCases
                if let i = all.firstIndex(of: state.customType) {
                    state.customType = all[(i + 1) % all.count]
                }
            } label: {
                Text(state.customType.emoji)
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("点击切换饮料类型 当前：\(state.customType.name)")
            TextField("1-5000", text: Binding(
                get: { state.customText },
                set: {
                    let digits = $0.filter { $0.isNumber }
                    // 超5000立即钳到5000 显示即所得
                    if let v = Int(digits), v > 5000 {
                        state.customText = "5000"
                    } else {
                        state.customText = digits
                    }
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 50)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            .onSubmit { commitCustomDrink() }
            .onExitCommand { state.editingCustom = false }
            // 空态显示系数 有输入显示换算结果 共用一个槽位 保证最坏情况不超宽
            if let v = Int(state.customText), v >= 1 {
                Text("\(Int((Double(v) * state.customType.ratio).rounded())) ml")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .monospacedDigit()
                    .fixedSize()
            } else {
                Text("×\(Int(state.customType.ratio * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize()
            }
            Spacer(minLength: 4)
            Button {
                commitCustomDrink()
            } label: {
                Text("记")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("记下")
            .help("记下")
        }
    }

    // 提交自定义量 校验 1-5000
    func commitCustomDrink() {
        defer {
            state.editingCustom = false
            state.customText = ""
        }
        guard let ml = Int(state.customText.trimmingCharacters(in: .whitespaces)),
              ml >= 1, ml <= 5000 else { return }
        logDrink(ml, type: state.customType)
    }

    // 快捷记录按钮 幽灵样式 细描边浅字 悬停才亮 不和大环抢戏
    // ml为nil时不显示数字（自定义按钮用） 三等分通栏 文字不换行
    func presetButton(_ icon: String, _ title: String, _ ml: Int?, id: String) -> some View {
        Button {
            if let ml {
                logDrink(ml)
            } else {
                // 再点一次收起
                state.editingCustom.toggle()
                state.customText = ""
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(ml.map { String($0) } ?? title)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .foregroundColor(state.hoverBtn == id ? .accentColor : .secondary)
            .background(state.hoverBtn == id ? AnyShapeStyle(Color.accentColor.opacity(0.08)) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(state.hoverBtn == id ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.12),
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            state.hoverBtn = h ? id : (state.hoverBtn == id ? nil : state.hoverBtn)
        }
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
            state.hoverGoal = false
            state.hoverBtn = nil
            state.markLayoutJump()
        }
    }

    // 底栏按钮 图标+小字 active/悬停时点亮主题色
    func controlButton(_ title: String, _ icon: String, _ key: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(.system(size: 9))
            }
            .frame(width: 36, height: 32)
            .foregroundColor((active || state.hoverBtn == title) ? Color.accentColor : Color.primary.opacity(0.5))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(key.first!), modifiers: .command)
        .onHover { hovering in
            state.hoverBtn = hovering ? title : (state.hoverBtn == title ? nil : state.hoverBtn)
        }
        .frame(maxWidth: .infinity)
    }

    // 三列数据列 数值带单位+名词标签
    func statCol(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.accentColor)
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
        let goal = todayGoal
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
                    .foregroundColor(.accentColor)
                Text("离 ")
                    .foregroundColor(.secondary)
                goalWord
                Text(" 还差 ")
                    .foregroundColor(.secondary)
                Text("\(goal - consumed) ml")
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
            }
        }
        .font(.system(size: 12))
    }

    // "今日目标"四个字 悬停显示当前数值 点击可改 只影响今天
    var goalWord: some View {
        Group {
            if state.editingGoal {
                TextField("", text: Binding(
                    get: { state.editingGoalText },
                    set: { state.editingGoalText = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(width: 46)
                .onSubmit { commitGoalEdit() }
                .onExitCommand { state.editingGoal = false }
            } else {
                // 悬停时原地显示目标数值 点击进编辑
                if state.hoverGoal {
                    Text("\(todayGoal) ml")
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .contentShape(Rectangle())
                        .onHover { state.hoverGoal = $0 }
                        .onTapGesture {
                            state.editingGoal = true
                            state.editingGoalText = "\(todayGoal)"
                        }
                } else {
                    Text("今日目标")
                        .foregroundColor(.secondary)
                        .contentShape(Rectangle())
                        .onHover { state.hoverGoal = $0 }
                        .onTapGesture {
                            state.editingGoal = true
                            state.editingGoalText = "\(todayGoal)"
                        }
                }
            }
        }
    }

    // 保存今日目标 500-10000合法 只写今天这个日期
    func commitGoalEdit() {
        defer {
            state.editingGoal = false
            state.editingGoalText = ""
        }
        guard let ml = Int(state.editingGoalText.trimmingCharacters(in: .whitespaces)) else { return }
        guard ml >= 500, ml <= 10000 else { return }
        db.setGoalOverride(date: Database.dayFormat.string(from: Date()), ml: ml)
    }

    // 右上角 点击循环 公历 -> 农历 -> 周五判断
    func topRightDate(_ date: Date) -> some View {
        Group {
            switch state.dateMode {
            case 1:
                Text(Self.lunarText(date))
            case 2:
                let isFriday = Calendar.current.component(.weekday, from: date) == 6
                if isFriday {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("今天是 ")
                        Text("周五")
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                } else {
                    Text("今天不是周五")
                }
            default:
                Text(Self.dayFormat.string(from: date))
            }
        }
        // 三种模式字号统一 11pt
        .font(.system(size: 11))
        .foregroundColor(.secondary)
        .contentShape(Rectangle())
        .onTapGesture { state.dateMode = (state.dateMode + 1) % 3 }
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

    // 左卡 剩余量 点击换单位 外圈进度=今日完成度 喝超了按0显示 不出负数
    var remainCard: some View {
        let remain = max(0, Double(todayGoal) - consumedML)
        return panelCard("剩余水量", remainText(remain),
                         progress: min(consumedML / Double(max(todayGoal, 1)), 1.0))
            .onTapGesture { state.unitIndex = (state.unitIndex + 1) % 3 }
    }

    // 右卡 下次提醒 点击切倒计时 外圈进度=临近下次提醒的程度
    func remindCard(_ now: Date) -> some View {
        let remainSec = max(0, state.nextRemind.timeIntervalSince(now))
        let countdown = 1 - remainSec / state.remindInterval
        return panelCard(state.showCountdown ? "倒计时" : "下次提醒", remindText(now),
                         progress: min(max(countdown, 0), 1), countdown: true)
            .onTapGesture { state.showCountdown.toggle() }
    }

    func panelCard(_ title: String, _ value: String, progress: Double? = nil, countdown: Bool = false) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        // 外圈进度 轨道+进度线 从顶部中央顺时针 倒计时卡加刻度和动点
        // 跳变瞬间和几何异常时只画轨道 装饰层暂停防错位闪现
        .overlay(
            GeometryReader { geo in
                let rectOk = geo.size.width > 10 && geo.size.width < 200
                    && geo.size.height > 10 && geo.size.height < 80
                let decorate = !state.layoutJumping && rectOk
                return ZStack {
                    // 轨道
                    RoundedRectOutlineShape.RoundedRectPartialShape(from: 0, to: 1, radius: 10)
                        .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 2))
                    if decorate && countdown {
                        // 时间刻度 60格 时钟式 每逢5主刻度长蓝 短灰
                        ForEach(0..<60, id: \.self) { i in
                            let isMajor = i % 5 == 0
                            RoundedRectOutlineShape.RoundedRectPartialShape(from: Double(i) / 60,
                                                                            to: Double(i) / 60 + (isMajor ? 0.008 : 0.004),
                                                                            radius: 10)
                                .stroke(isMajor ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.18),
                                        style: StrokeStyle(lineWidth: isMajor ? 2.5 : 1.5))
                        }
                    }
                    if let progress, decorate {
                        let clamped = min(max(progress, 0), 1)
                        // 进度线
                        RoundedRectOutlineShape.RoundedRectPartialShape(from: 0, to: clamped, radius: 10)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .animation(.easeOut(duration: 0.4), value: progress)
                        if countdown {
                            // 倒计时动点 走到哪亮到哪
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                                .position(RoundedRectOutlineShape.point(in: CGRect(origin: .zero, size: geo.size), t: clamped, radius: 10))
                        }
                    }
                }
                // 撑满测量区 坐标系原点对齐卡片左上角 position才准
                .frame(width: geo.size.width, height: geo.size.height)
            }
        )
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
