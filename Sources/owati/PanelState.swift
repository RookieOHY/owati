import SwiftUI
import CoreGraphics

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
    @Published var settingsTab = 0        // 设置窗口侧栏 0音效 1提醒 2关于
    @Published var settingsSearch = ""    // 设置窗口搜索框
    @Published var updateStatus = ""      // 检查更新结果文案
    var pageHeight: CGFloat = 0               // 主页滑动区高度 实验室页钉这个高度 滑动期间窗口不变
    var wasGoalReached = false            // 上次是否已达标 算跨越用
    // 下次提醒时间 引擎驱动 面板右卡显示/倒计时共用
    @Published var nextRemind = Date().addingTimeInterval(45 * 60)
    var remindInterval: TimeInterval = 45 * 60  // 间隔秒 倒计时环算进度用
    @Published var remindCardText = ""          // 提醒卡文案 该喝水了/回来啦
    @Published var remindCardVisible = false    // 提醒卡在不在
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

    // MARK: 提醒引擎
    // 进程一起来就跑 与面板开不开无关
    func startRemindEngine() {
        scheduleNext(from: Date())
        remindTimer?.invalidate()
        remindTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.remindTick()
        }
    }

    // 排下次提醒
    func scheduleNext(from: Date) {
        let min = AppConfig.shared.remindIntervalMin
        remindInterval = TimeInterval(min * 60)
        nextRemind = from.addingTimeInterval(remindInterval)
    }

    // 记了一杯 从现在重新计时 收卡
    func markLogged() {
        scheduleNext(from: Date())
        afkCatchup = false
        ReminderCard.shared.hide()
    }

    // 提醒卡上的稍后 10分钟后再来
    func snoozeCard(_ minutes: Int = 10) {
        nextRemind = Date().addingTimeInterval(TimeInterval(minutes * 60))
        afkCatchup = false
        ReminderCard.shared.hide()
    }

    // 快速记一杯 提醒卡专用 一杯水量+水
    func quickLogCup() {
        let c = AppConfig.shared
        let id = Database.shared.addDrink(c.cupML, type: .water)
        guard id != 0 else { return }
        SoundPlayer.shared.playLog()   // 和面板同一声 开罐音
        drinkPulse += 1
        setUndo(.added(id: id), text: "已记录 \(c.cupML) ml")
        // 先重新计时 但卡留着 让进度条动完 0.6秒后再收
        scheduleNext(from: Date())
        afkCatchup = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ReminderCard.shared.hide()
        }
    }

    // 每5秒巡检一次 到点才动作
    private func remindTick() {
        let now = Date()
        let idle = idleSeconds()
        // 离开期间跳过的 人回来了补一次
        if afkCatchup && idle < afkThreshold && !remindCardVisible {
            afkCatchup = false
            scheduleNext(from: now)
            ReminderCard.shared.show(text: "回来啦 先喝杯水")
            return
        }
        guard now >= nextRemind, !remindCardVisible else { return }
        // 人不在 本次静默滑过 等回来补
        if idle >= afkThreshold {
            afkCatchup = true
            scheduleNext(from: now)
            return
        }
        // 配置闸门 时间段/提醒日/休息段
        guard remindAllowed(now) else {
            scheduleNext(from: now)
            return
        }
        scheduleNext(from: now)
        ReminderCard.shared.show(text: "该喝水了")
    }

    // 用户键鼠空闲秒数 无需任何权限
    private func idleSeconds() -> TimeInterval {
        let types: [CGEventType] = [.leftMouseDown, .rightMouseDown, .otherMouseDown,
                                    .mouseMoved, .keyDown, .scrollWheel]
        return types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }

    // 提醒时段判断 时间段内+提醒日+非休息段
    private func remindAllowed(_ now: Date) -> Bool {
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
