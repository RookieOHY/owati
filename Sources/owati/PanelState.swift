import SwiftUI
import CoreGraphics
import AppKit

// 最近一次可撤销的操作
enum UndoAction {
    case added(id: Int64)                         // 新增 直接删行
    case deleted(id: Int64, date: Date, ml: Int, type: DrinkType)  // 删除 按原时间插回
    case edited(id: Int64, oldML: Int)            // 修改 回退到旧值
}

// 面板交互状态
final class PanelState: ObservableObject {
    static let shared = PanelState()
    @Published var unitIndex = 0          // 剩余 0 ml 1 L 2 升
    @Published var showCountdown = false  // 下次提醒 时刻 <-> 倒计时
    @Published var hoverDay: Int? = nil   // 周水滴悬停的列序号
    @Published var hoverConfirmed: Int? = nil // 过了延迟还悬停才亮tooltip 挡布局跳变时的瞬时误报
    @Published var hoverRow: Int64? = nil // 时间线悬停的记录id
    @Published var showDetail = false     // 今日详情 展开/收起
    @Published var editingId: Int64? = nil    // 正在改ml的记录id
    @Published var editingText = ""           // 编辑框当前内容
    var editingOldML = 0                      // 进编辑前的量 算撤销用
    @Published var undo: UndoAction? = nil    // 最近一次可撤销操作
    @Published var undoText = ""
    @Published var dateMode = 0          // 右上角 0公历 1农历 2周五判断 点击循环
    @Published var showLab = false       // 实验室页 面板左滑进入
    @Published var hoverGoal = false     // 悬停"今日目标" 显示数值提示
    @Published var hoverBtn: String? = nil   // 底栏悬停的按钮名 悬停亮蓝
    @Published var editingGoal = false       // 正在改今日目标
    @Published var editingGoalText = ""
    @Published var editingCustom = false     // 正在自定义量记录
    @Published var customText = ""
    @Published var customType: DrinkType = .water  // 自定义记录选的类型
    @Published var celebrate = false      // 达标庆祝 一次性
    @Published var drinkPulse = 0         // 记录一笔后+1 驱动面板立即刷新
    @Published var panelHeight: CGFloat = 0   // 内容实测高度 用于同步窗口
    @Published var layoutJumping = false      // 窗口跳变中 装饰层暂停绘制防错位闪现
    @Published var settingsTab = 0        // 设置窗口侧栏 0通用 1关于
    @Published var helpOpen: String? = nil // 设置页问号帮助当前打开的行
    @Published var statsHoverBar: Int? = nil   // 统计柱状图悬停列
    @Published var statsRange = 0         // 统计窗 0近7天 1近30天 卡片跟着切
    @Published var statsHoverCard: Int? = nil  // 统计指标卡悬停序号 驱动浮起动效
    @Published var achvHoverId: String? = nil  // 成就窗悬停的徽章id
    @Published var achvDetailId: String? = nil // 成就窗点开的详情徽章id
    @Published var badgeToastVisible = false   // 解锁toast在不在
    @Published var badgeToastName = ""         // toast里的徽章名
    @Published var badgeToastIcon = "trophy.fill"
    @Published var statsChartKind = 0     // 统计每日水合图形态 0水滴 1柱状 2折线 默认水滴
    var pageHeight: CGFloat = 0               // 主页滑动区高度 实验室页钉这个高度 滑动期间窗口不变
    var wasGoalReached = false            // 上次是否已达标 算跨越用
    // 下次提醒时间 引擎驱动 面板右卡显示/倒计时共用
    @Published var nextRemind = Date().addingTimeInterval(45 * 60)
    var remindInterval: TimeInterval = 45 * 60  // 间隔秒 倒计时环算进度用
    @Published var remindCardText = ""          // 提醒卡文案 该喝水了/回来啦
    @Published var remindCardVisible = false    // 提醒卡在不在
    @Published var fullScreenTip = ""           // 全屏提醒的tips
    @Published var fullScreenVisible = false    // 全屏提醒在不在
    @Published var fullScreenDeadline = Date()  // 全屏自动关闭时刻
    @Published var fullScreenLeft = 30          // 全屏剩余秒数 引擎Timer驱动 TimelineView不跳
    @Published var menuBarImage = NSImage(size: NSSize(width: 22, height: 22))  // 菜单栏动态图标 环+倒计时
    @Published var cardBreath = false           // 水滴呼吸动画驱动
    private var menuGlyph: NSImage?
    private var menuTimer: Timer?
    var skipStreak = 0                          // 连续跳过且没记录的次数 够2次换催促tips

    // tips池 轮换防审美疲劳
    static let fullScreenTips = [
        "小口慢饮 更利吸收",
        "餐后半小时再补水更舒服",
        "咖啡因利尿 喝完咖啡记得补一杯",
        "长时间说话 也要润润喉",
        "起身接水 顺便活动下腰颈",
        "运动出汗后 别一次猛灌",
        "空调房里水分蒸发快",
        "睡前一小时少喝 夜里少起夜",
        "温水更友好 肠胃没负担",
        "早上第一杯 唤醒一天代谢",
    ]
    // 催促款 连跳2次还没记录就换这套 温和升级
    static let urgingTips = [
        "已经连续跳过啦 身体在等水",
        "水杯就在手边 顺手一杯",
        "连着两次没喝 今天的goal悬了",
        "别让提醒变成背景音 来一杯吧",
    ]
    // 会议应用关键词 命中就暂停提醒
    static let meetingKeywords = ["zoom", "wemeet", "teams", "lark", "feishu", "webex", "dingtalk", "meeting"]
    private var remindTimer: Timer?
    private var afkCatchup = false              // 刚才因为离开跳过了 回来要补
    private let afkThreshold: TimeInterval = 300

    private var hoverWork: DispatchWorkItem?
    private var undoToken = 0
    private var undoWork: DispatchWorkItem?
    private var jumpToken = 0
    private var jumpWork: DispatchWorkItem?

    // 标记窗口跳变 80ms内装饰层不画 防几何错位闪现
    func markLayoutJump() {
        layoutJumping = true
        jumpToken += 1
        let token = jumpToken
        jumpWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            if self?.jumpToken == token {
                self?.layoutJumping = false
            }
        }
        jumpWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: w)
    }

    // 波浪相位累加器 逐帧推进 庆祝时加速
    final class WaveClock {
        var phase: Double = 0
        var last: Date?
    }
    let waveClock = WaveClock()

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

    // MARK: 徽章评估
    // 全部条件实时重算 首次调用只静默建档不弹历史成就 之后新解锁逐条弹toast
    private var knownBadges: Set<String>? = nil
    private var pendingToasts: [(name: String, icon: String)] = []
    private var toastToken = 0
    private var toastWork: DispatchWorkItem?

    // 新货机制 开窗时快照当次的新徽章 展位挂NEW角标 底栏挂蓝点
    @Published var newBadgeIds: Set<String> = []   // 本次开窗时未看过的已解锁徽章
    @Published var hasNewBadges = false            // 底栏成就按钮的蓝点

    // 打开陈列室 快照新徽章后全部标记已看 蓝点即消
    func openAchievementRoom() {
        let earned = Achievements.earnedIDs(db: Database.shared)
        newBadgeIds = earned.subtracting(AppConfig.shared.achvSeen)
        AppConfig.shared.achvSeen.formUnion(earned)
        hasNewBadges = false
    }

    // 点开某徽章详情 单独消它的NEW
    func markAchvSeen(_ id: String) {
        newBadgeIds.remove(id)
        AppConfig.shared.achvSeen.insert(id)
        let earned = Achievements.earnedIDs(db: Database.shared)
        hasNewBadges = !earned.isSubset(of: AppConfig.shared.achvSeen)
    }

    func evaluateBadges() {
        let earned = Achievements.earnedIDs(db: Database.shared)
        guard let known = knownBadges else {
            knownBadges = earned
            syncNewBadges(earned)
            return
        }
        guard !earned.isSubset(of: known) else { return }
        let fresh = earned.subtracting(known)
        knownBadges = earned
        syncNewBadges(earned)
        for b in Achievements.all where fresh.contains(b.id) {
            pendingToasts.append((b.name, b.icon))
        }
        if !badgeToastVisible { popToast() }
    }

    private func syncNewBadges(_ earned: Set<String>) {
        hasNewBadges = !earned.isSubset(of: AppConfig.shared.achvSeen)
    }

    // 弹一条3.5秒 多枚排队 上一条收起后接下一条
    private func popToast() {
        guard let next = pendingToasts.first else { return }
        pendingToasts.removeFirst()
        toastToken += 1
        let token = toastToken
        withAnimation(.easeOut(duration: 0.3)) {
            badgeToastName = next.name
            badgeToastIcon = next.icon
            badgeToastVisible = true
        }
        SoundPlayer.shared.playLog()   // 复用记录音 轻一声
        let w = DispatchWorkItem { [weak self] in
            guard let self, self.toastToken == token else { return }
            withAnimation(.easeIn(duration: 0.25)) { self.badgeToastVisible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.popToast()
            }
        }
        toastWork?.cancel()
        toastWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: w)
    }

    // MARK: 提醒引擎
    // 进程一起来就跑 与面板开不开无关
    func startRemindEngine() {
        scheduleNext(from: Date())
        loadMenuGlyph()
        renderMenuBar()
        startMenuBarTimer()
        remindTimer?.invalidate()
        remindTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.remindTick()
        }
    }

    // 菜单栏图标每秒重绘 倒计时文本+喝水进度环 滴答清单同款模板单色
    private func startMenuBarTimer() {
        menuTimer?.invalidate()
        menuTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.renderMenuBar()
        }
    }

    private func loadMenuGlyph() {
        // 用44px源 22pt在Retina正好2x 画12pt(环内)是缩小不糊 22px源放大会糊
        guard let path = Res.path("demo/png/owati-44.png") else { return }
        menuGlyph = NSImage(contentsOfFile: path)
    }

    func renderMenuBar() {
        let now = Date()
        let sleeping = remindSleeping(now)
        let c = AppConfig.shared
        let goal = Database.shared.todayGoalOverride() ?? c.dailyGoalML
        let progress = goal > 0 ? min(1, Double(Database.shared.todayTotalML()) / Double(goal)) : 0
        // 倒计时文本 滴答清单同款 恒 h:mm:ss
        var text: String?
        if c.menuCountdown && !sleeping {
            let s = max(0, Int(nextRemind.timeIntervalSince(now)))
            text = String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
        }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let iconW: CGFloat = c.menuRing ? 26 : 22
        let w = iconW + (text != nil ? 6 + ceil((text! as NSString).size(withAttributes: [.font: font]).width) : 0)
        let img = NSImage(size: NSSize(width: w, height: 22))
        // lockFocus离屏只出1x位图 Retina菜单栏拉伸2倍必糊
        // 显式建2x位图 像素翻倍 坐标仍按点画 亮屏才清晰
        let scale: CGFloat = 2
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(w * scale), pixelsHigh: Int(22 * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: w, height: 22)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let cx = iconW / 2, cy: CGFloat = 11, r: CGFloat = 9.5
        // 进度环 track + 喝水进度弧 加粗到2pt
        if c.menuRing {
            let track = NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            NSColor.black.withAlphaComponent(0.3).setStroke()
            track.lineWidth = 2
            track.stroke()
            if progress > 0.003 {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: r,
                              startAngle: 90, endAngle: 90 - progress * 360, clockwise: true)
                NSColor.black.setStroke()
                arc.lineWidth = 2
                arc.lineCapStyle = .round
                arc.stroke()
            }
        }
        // 中心水滴 有环缩进环内 关环恢复原大小
        if let glyph = menuGlyph {
            let g: CGFloat = c.menuRing ? 12 : 22
            glyph.draw(in: NSRect(x: cx - g / 2, y: cy - g / 2, width: g, height: g))
        }
        // 倒计时文本 基线用字体度量正推: 视觉中心(11) = y + ascender - capHeight/2
        if let t = text {
            (t as NSString).draw(
                at: NSPoint(x: iconW + 6, y: 11 - font.ascender + font.capHeight / 2),
                withAttributes: [.font: font, .foregroundColor: NSColor.black.withAlphaComponent(0.9)])
        }
        NSGraphicsContext.restoreGraphicsState()
        img.addRepresentation(rep)
        img.isTemplate = true
        menuBarImage = img
    }

    // 排下次提醒 达标后按节奏倍数放缓 面板倒计时同步
    func scheduleNext(from: Date) {
        var min = AppConfig.shared.remindIntervalMin
        let goal = Database.shared.todayGoalOverride() ?? AppConfig.shared.dailyGoalML
        if AppConfig.shared.goalIntervalMult > 1 && Database.shared.todayTotalML() >= goal {
            min *= AppConfig.shared.goalIntervalMult
        }
        remindInterval = TimeInterval(min * 60)
        nextRemind = from.addingTimeInterval(remindInterval)
        renderMenuBar()   // 下次提醒变了 菜单栏倒计时同步
    }

    // 记了一杯 从现在重新计时 收卡
    func markLogged() {
        scheduleNext(from: Date())
        afkCatchup = false
        ReminderCard.shared.hide()
    }

    private var cdTimer: Timer?

    // 全屏倒计时 1秒递减发布 TimelineView在浮层里不跳 引擎Timer驱动
    func startFullScreenCountdown() {
        fullScreenLeft = 30
        cdTimer?.invalidate()
        cdTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.fullScreenVisible else {
                self?.cdTimer?.invalidate()
                self?.cdTimer = nil
                return
            }
            self.fullScreenLeft = max(0, self.fullScreenLeft - 1)
            if self.fullScreenLeft <= 0 {
                self.cdTimer?.invalidate()
                self.cdTimer = nil
                self.skipStreak += 1
                FullScreenReminder.shared.hide()
            }
        }
    }

    func stopFullScreenCountdown() {
        cdTimer?.invalidate()
        cdTimer = nil
    }

    // 提醒卡上的稍后 10分钟后再来 算一次跳过
    func snoozeCard(_ minutes: Int = 10) {
        nextRemind = Date().addingTimeInterval(TimeInterval(minutes * 60))
        skipStreak += 1
        afkCatchup = false
        ReminderCard.shared.hide()
        FullScreenReminder.shared.hide()
    }

    // 快速记一笔 量可传 提醒卡/全屏页共用
    func quickLog(ml: Int) {
        let id = Database.shared.addDrink(ml, type: .water)
        guard id != 0 else { return }
        skipStreak = 0   // 记录了 跳过连击清零 tips回到温和池
        SoundPlayer.shared.playLog()   // 和面板同一声 开罐音
        drinkPulse += 1
        evaluateBadges()   // 快速记录也算解锁时点
        setUndo(.added(id: id), text: "已记录 \(ml) ml")
        // 先重新计时 但载体留着 让进度条动完 0.6秒后再收
        scheduleNext(from: Date())
        afkCatchup = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ReminderCard.shared.hide()
            FullScreenReminder.shared.hide()
        }
    }

    // 快速记一杯 提醒卡专用 一杯水量+水
    func quickLogCup() {
        quickLog(ml: AppConfig.shared.cupML)
    }

    // 固定闸门不过(窗口外/非提醒日/勿扰段) = 休眠态 面板显示休眠占位
    func remindSleeping(_ now: Date) -> Bool {
        !remindAllowed(now)
    }

    // 每5秒巡检一次 到点才动作
    private func remindTick() {
        let now = Date()
        let idle = idleSeconds()
        // 全屏页到自动关闭时刻 算一次跳过
        if fullScreenVisible && now >= fullScreenDeadline {
            skipStreak += 1
            FullScreenReminder.shared.hide()
        }
        // 会议应用在前台 暂停这轮 2分钟后再看
        if AppConfig.shared.meetingPause && Self.frontmostIsMeeting() {
            nextRemind = now.addingTimeInterval(120)
            return
        }
        // 超额静音 达到阈值比例后今天彻底安静
        let goal = Database.shared.todayGoalOverride() ?? AppConfig.shared.dailyGoalML
        let total = Database.shared.todayTotalML()
        let silence = AppConfig.shared.overGoalSilence
        if silence > 0 && goal > 0 && total * 100 >= goal * silence {
            scheduleNext(from: now)
            return
        }
        // 离开期间跳过的 人回来了补一次
        if afkCatchup && idle < afkThreshold && !remindCardVisible && !fullScreenVisible {
            afkCatchup = false
            scheduleNext(from: now)
            showReminder(text: "回来啦 先喝杯水")
            return
        }
        guard now >= nextRemind, !remindCardVisible, !fullScreenVisible else { return }
        // 人不在 本次静默滑过 等回来补
        if idle >= afkThreshold {
            afkCatchup = true
            scheduleNext(from: now)
            return
        }
        // 配置闸门 时间段/提醒日/勿扰
        guard remindAllowed(now) else {
            scheduleNext(from: now)
            return
        }
        scheduleNext(from: now)
        showReminder(text: "该喝水了")
    }

    // 按设置的提醒方式弹出载体 达标后全屏自动降级为卡片 文案换保持款
    private func showReminder(text: String) {
        let goal = Database.shared.todayGoalOverride() ?? AppConfig.shared.dailyGoalML
        let total = Database.shared.todayTotalML()
        if total >= goal {
            ReminderCard.shared.show(text: "保持状态 · 随手一杯")
            SoundPlayer.shared.playRemind()
            return
        }
        if AppConfig.shared.reminderStyle == 1 {
            let pool = skipStreak >= max(1, AppConfig.shared.nudgeSkips) ? Self.urgingTips : Self.fullScreenTips
            FullScreenReminder.shared.show(tip: pool.randomElement() ?? "")
        } else {
            ReminderCard.shared.show(text: text)
        }
        SoundPlayer.shared.playRemind()   // 提醒出现也有一声 轻的
    }

    // 前台应用命中会议关键词
    static func frontmostIsMeeting() -> Bool {
        let app = NSWorkspace.shared.frontmostApplication
        let s = ((app?.bundleIdentifier ?? "") + " " + (app?.localizedName ?? "")).lowercased()
        return meetingKeywords.contains { s.contains($0) }
    }

    // 用户键鼠空闲秒数 无需任何权限
    private func idleSeconds() -> TimeInterval {
        let types: [CGEventType] = [.leftMouseDown, .rightMouseDown, .otherMouseDown,
                                    .mouseMoved, .keyDown, .scrollWheel]
        return types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }

    // 提醒时段判断 时间段内+提醒日+非休息段
    func remindAllowed(_ now: Date) -> Bool {
        let c = AppConfig.shared
        let cal = Calendar.current
        guard c.remindDays.contains(cal.component(.weekday, from: now)) else { return false }
        func mins(_ s: String) -> Int {
            let p = s.split(separator: ":").compactMap { Int($0) }
            return p.count == 2 ? p[0] * 60 + p[1] : 0
        }
        let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        guard nowMin >= mins(c.remindStart), nowMin <= mins(c.remindEnd) else { return false }
        if c.restEnabled, nowMin >= mins(c.restStart), nowMin <= mins(c.restEnd) { return false }
        return true
    }
}
