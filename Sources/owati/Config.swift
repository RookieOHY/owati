import SwiftUI
import Combine
import AppKit
import ServiceManagement

// 全局配置 存 UserDefaults
final class AppConfig: ObservableObject {
    static let shared = AppConfig()

    private let ud = UserDefaults.standard

    // 配置变更事件 PanelState订阅处理 解除Config→PanelState反向耦合
    enum Change { case goal, goalInterval, menuDisplay }
    var onChange: ((Change) -> Void)?

    // 每日喝水目标 ml
    @Published var dailyGoalML: Int {
        didSet {
            ud.set(dailyGoalML, forKey: "dailyGoalML")
            // 目标变了 streak/单日达标率/满勤周口径全跟着变 徽章重评(由订阅方处理)
            onChange?(.goal)
        }
    }
    // 提醒间隔 分钟
    @Published var remindIntervalMin: Int {
        didSet { ud.set(remindIntervalMin, forKey: "remindIntervalMin") }
    }
    // 提醒日 1=周日 2=周一 ... 7=周六
    @Published var remindDays: Set<Int> {
        didSet { ud.set(Array(remindDays), forKey: "remindDays") }
    }
    // 提醒时间段 开始/结束 "09:00" "19:00"
    @Published var remindStart: String {
        didSet { ud.set(remindStart, forKey: "remindStart") }
    }
    @Published var remindEnd: String {
        didSet { ud.set(remindEnd, forKey: "remindEnd") }
    }
    // 休息时间 段内不提醒(如午休)
    @Published var restEnabled: Bool {
        didSet { ud.set(restEnabled, forKey: "restEnabled") }
    }
    @Published var restStart: String {
        didSet { ud.set(restStart, forKey: "restStart") }
    }
    @Published var restEnd: String {
        didSet { ud.set(restEnd, forKey: "restEnd") }
    }
    // 引导是否完成
    @Published var didOnboarding: Bool {
        didSet { ud.set(didOnboarding, forKey: "didOnboarding") }
    }
    // 快捷杯量 一杯/一瓶
    @Published var cupML: Int {
        didSet { ud.set(cupML, forKey: "cupML") }
    }
    @Published var bottleML: Int {
        didSet { ud.set(bottleML, forKey: "bottleML") }
    }
    // 记录成功的开罐音效开关
    @Published var soundOn: Bool {
        didSet { ud.set(soundOn, forKey: "soundOn") }
    }
    // 记录音效种类 Sfx.rawValue
    @Published var soundEffect: String {
        didSet { ud.set(soundEffect, forKey: "soundEffect") }
    }
    // 外观 0跟随系统 1浅色 2深色
    @Published var appearance: Int {
        didSet { ud.set(appearance, forKey: "appearance"); Self.applyAppearance(appearance) }
    }
    // 提醒方式 0浮动卡片 1全屏页面
    @Published var reminderStyle: Int {
        didSet { ud.set(reminderStyle, forKey: "reminderStyle") }
    }
    // 提醒出现音效 苹果系统音效名 空串=跟随记录音效
    @Published var remindSound: String {
        didSet { ud.set(remindSound, forKey: "remindSound") }
    }
    // 连跳几次后tips换催促款
    @Published var nudgeSkips: Int {
        didSet { ud.set(nudgeSkips, forKey: "nudgeSkips") }
    }
    // 稍后时长 分钟
    @Published var snoozeMin: Int {
        didSet { ud.set(snoozeMin, forKey: "snoozeMin") }
    }
    // 达标后提醒间隔倍数 1不变 2温和 3更缓
    @Published var goalIntervalMult: Int {
        didSet {
            ud.set(goalIntervalMult, forKey: "goalIntervalMult")
            // 改节奏立即重排 面板倒计时同步(由订阅方处理)
            onChange?(.goalInterval)
        }
    }
    // 超额静音阈值 0关闭 150/200=超额百分比后彻底安静
    @Published var overGoalSilence: Int {
        didSet { ud.set(overGoalSilence, forKey: "overGoalSilence") }
    }
    // 菜单栏图标外画喝水进度环
    @Published var menuRing: Bool {
        didSet {
            ud.set(menuRing, forKey: "menuRing")
            onChange?(.menuDisplay)   // 立即重绘(由订阅方处理)
        }
    }
    // 菜单栏图标右侧显示倒计时文本
    @Published var menuCountdown: Bool {
        didSet {
            ud.set(menuCountdown, forKey: "menuCountdown")
            onChange?(.menuDisplay)
        }
    }
    // 会议应用在前台自动暂停提醒
    @Published var meetingPause: Bool {
        didSet { ud.set(meetingPause, forKey: "meetingPause") }
    }
    // 已查看过的徽章id 陈列室NEW角标用
    @Published var achvSeen: Set<String> {
        didSet { ud.set(Array(achvSeen), forKey: "achvSeen") }
    }
    // 开机自启动 SMAppService 真实状态为准
    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch { /* 裸可执行(未打包)注册不了 打包成app后生效 */ }
            ud.set(SMAppService.mainApp.status == .enabled, forKey: "launchAtLogin")
        }
    }

    private init() {
        let d = UserDefaults.standard
        dailyGoalML = d.object(forKey: "dailyGoalML") as? Int ?? 2000
        remindIntervalMin = d.object(forKey: "remindIntervalMin") as? Int ?? 45
        remindDays = Set(d.object(forKey: "remindDays") as? [Int] ?? [2, 3, 4, 5, 6])
        remindStart = d.string(forKey: "remindStart") ?? "09:00"
        remindEnd = d.string(forKey: "remindEnd") ?? "19:00"
        restEnabled = d.object(forKey: "restEnabled") as? Bool ?? true
        restStart = d.string(forKey: "restStart") ?? "12:00"
        restEnd = d.string(forKey: "restEnd") ?? "13:00"
        didOnboarding = d.bool(forKey: "didOnboarding")
        cupML = d.object(forKey: "cupML") as? Int ?? 250
        bottleML = d.object(forKey: "bottleML") as? Int ?? 500
        soundOn = d.object(forKey: "soundOn") as? Bool ?? true
        soundEffect = d.string(forKey: "soundEffect") ?? Sfx.canFizz.rawValue
        appearance = d.object(forKey: "appearance") as? Int ?? 0
        reminderStyle = d.object(forKey: "reminderStyle") as? Int ?? 0
        remindSound = d.string(forKey: "remindSound") ?? ""
        nudgeSkips = d.object(forKey: "nudgeSkips") as? Int ?? 2
        snoozeMin = d.object(forKey: "snoozeMin") as? Int ?? 10
        goalIntervalMult = d.object(forKey: "goalIntervalMult") as? Int ?? 2
        overGoalSilence = d.object(forKey: "overGoalSilence") as? Int ?? 150
        menuRing = d.object(forKey: "menuRing") as? Bool ?? true
        menuCountdown = d.object(forKey: "menuCountdown") as? Bool ?? true
        meetingPause = d.object(forKey: "meetingPause") as? Bool ?? true
        achvSeen = Set(d.stringArray(forKey: "achvSeen") ?? [])
        launchAtLogin = d.object(forKey: "launchAtLogin") as? Bool ?? false
        // 兜底 空的提醒日回落到工作日
        if remindDays.isEmpty { remindDays = [2, 3, 4, 5, 6] }
        Self.applyAppearance(appearance)
    }

    // 外观切换 跟随时清nil交给系统
    static func applyAppearance(_ v: Int) {
        NSApplication.shared.appearance = v == 1 ? NSAppearance(named: .aqua) : v == 2 ? NSAppearance(named: .darkAqua) : nil
    }

    // 导出用 配置快照
    func configSnapshot() -> [String: Any] {
        [
            "dailyGoalML": dailyGoalML,
            "remindIntervalMin": remindIntervalMin,
            "remindDays": Array(remindDays),
            "remindStart": remindStart,
            "remindEnd": remindEnd,
            "restEnabled": restEnabled,
            "restStart": restStart,
            "restEnd": restEnd,
            "soundOn": soundOn,
            "soundEffect": soundEffect,
            "remindSound": remindSound,
            "reminderStyle": reminderStyle,
            "meetingPause": meetingPause,
            "nudgeSkips": nudgeSkips,
            "goalIntervalMult": goalIntervalMult,
            "overGoalSilence": overGoalSilence,
            "cupML": cupML,
            "bottleML": bottleML,
            "menuRing": menuRing,
            "menuCountdown": menuCountdown,
        ]
    }

    // 导入用 逐项恢复 有的才写
    func applyImport(_ d: [String: Any]) {
        if let v = d["dailyGoalML"] as? Int { dailyGoalML = v }
        if let v = d["remindIntervalMin"] as? Int { remindIntervalMin = v }
        if let v = d["remindDays"] as? [Int] { let s = Set(v); if !s.isEmpty { remindDays = s } }
        if let v = d["remindStart"] as? String { remindStart = v }
        if let v = d["remindEnd"] as? String { remindEnd = v }
        if let v = d["restEnabled"] as? Bool { restEnabled = v }
        if let v = d["restStart"] as? String { restStart = v }
        if let v = d["restEnd"] as? String { restEnd = v }
        if let v = d["soundOn"] as? Bool { soundOn = v }
        if let v = d["soundEffect"] as? String { soundEffect = v }
        if let v = d["remindSound"] as? String { remindSound = v }
        if let v = d["reminderStyle"] as? Int { reminderStyle = v }
        if let v = d["meetingPause"] as? Bool { meetingPause = v }
        if let v = d["nudgeSkips"] as? Int { nudgeSkips = v }
        if let v = d["goalIntervalMult"] as? Int { goalIntervalMult = v }
        if let v = d["overGoalSilence"] as? Int { overGoalSilence = v }
        if let v = d["cupML"] as? Int { cupML = v }
        if let v = d["bottleML"] as? Int { bottleML = v }
        if let v = d["menuRing"] as? Bool { menuRing = v }
        if let v = d["menuCountdown"] as? Bool { menuCountdown = v }
    }
}
