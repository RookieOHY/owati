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
    @Published var celebrate = false      // 达标庆祝 一次性
    @Published var panelHeight: CGFloat = 0   // 内容实测高度 用于同步窗口
    @Published var layoutJumping = false      // 窗口跳变中 装饰层暂停绘制防错位闪现
    var pageHeight: CGFloat = 0               // 主页滑动区高度 实验室页钉这个高度 滑动期间窗口不变
    var wasGoalReached = false            // 上次是否已达标 算跨越用
    // 假数据 下次提醒按启动时间+间隔算 之后由提醒器接管
    let nextRemind = Date().addingTimeInterval(45 * 60)
    let remindInterval: TimeInterval = 45 * 60  // 提醒间隔 倒计时环算进度用

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
}
