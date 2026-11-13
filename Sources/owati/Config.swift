import SwiftUI
import Combine
import AppKit
import ServiceManagement

// 全局配置 存 UserDefaults
final class AppConfig: ObservableObject {
    static let shared = AppConfig()

    private let ud = UserDefaults.standard

    // 每日喝水目标 ml
    @Published var dailyGoalML: Int {
        didSet { ud.set(dailyGoalML, forKey: "dailyGoalML") }
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
    // 快捷杯量 一杯/一瓶 实验室可改
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
    // 达标后提醒间隔倍数 1不变 2温和 3更缓
    @Published var goalIntervalMult: Int {
        didSet {
            ud.set(goalIntervalMult, forKey: "goalIntervalMult")
            // 改节奏立即重排 面板倒计时同步
            PanelState.shared.scheduleNext(from: Date())
        }
    }
    // 超额静音阈值 0关闭 150/200=超额百分比后彻底安静
    @Published var overGoalSilence: Int {
        didSet { ud.set(overGoalSilence, forKey: "overGoalSilence") }
    }
    // 会议应用在前台自动暂停提醒
    @Published var meetingPause: Bool {
        didSet { ud.set(meetingPause, forKey: "meetingPause") }
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
        goalIntervalMult = d.object(forKey: "goalIntervalMult") as? Int ?? 2
        overGoalSilence = d.object(forKey: "overGoalSilence") as? Int ?? 150
        meetingPause = d.object(forKey: "meetingPause") as? Bool ?? true
        launchAtLogin = d.object(forKey: "launchAtLogin") as? Bool ?? false
        // 兜底 空的提醒日回落到工作日
        if remindDays.isEmpty { remindDays = [2, 3, 4, 5, 6] }
        Self.applyAppearance(appearance)
    }

    // 外观切换 跟随时清nil交给系统
    static func applyAppearance(_ v: Int) {
        NSApplication.shared.appearance = v == 1 ? NSAppearance(named: .aqua) : v == 2 ? NSAppearance(named: .darkAqua) : nil
    }
}
