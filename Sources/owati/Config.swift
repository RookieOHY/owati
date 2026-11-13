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
