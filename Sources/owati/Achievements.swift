import SwiftUI

// MARK: 徽章成就体系
// 条件全部从 drink_records 实时计算 无解锁存档 撤销/改量后条件自动回退
// 设计参照: 华为运动健康(单次/累计/连续三维 未解锁点看条件自动点亮)
//          Apple里程碑叠加 Habitica灰态可辨 微信读书容错口径(今日未达标不算断)

// 徽章系列 分组展示
enum BadgeSeries: CaseIterable {
    case streak    // 连续达标
    case volume    // 累计总量
    case cups      // 累计杯数
    case special   // 高光时刻 单日与彩蛋

    var title: String {
        switch self {
        case .streak: return "连续达标"
        case .volume: return "累计总量"
        case .cups: return "累计杯数"
        case .special: return "高光时刻"
        }
    }

    var icon: String {
        switch self {
        case .streak: return "calendar"
        case .volume: return "drop.fill"
        case .cups: return "mug.fill"
        case .special: return "sparkles"
        }
    }
}

// 条件种类 决定当前值怎么算
enum BadgeKind {
    case streak       // 当前连续达标天数
    case volume       // 全库累计水合ml
    case cups         // 全库累计杯数
    case firstLog     // 记过第一笔 0/1
    case overGoalDay  // 历史单日最高达标率% 150解锁
    case friday       // 达标过的周五次数
}

struct Badge: Identifiable {
    let id: String
    let series: BadgeSeries
    let kind: BadgeKind
    let name: String
    let icon: String      // 奖牌内SF图标
    let condition: String // 获取条件文案
    let target: Int       // volume单位ml 其余为天/杯/次/%

    // 当前值 与target同口径 volume=ml overGoalDay=%
    func currentValue(db: Database) -> Int {
        switch kind {
        case .streak:
            return db.streakDays(goalML: AppConfig.shared.dailyGoalML)
        case .volume:
            return db.totalAllML()
        case .cups:
            return db.totalCups()
        case .firstLog:
            return min(db.totalCups(), 1)
        case .overGoalDay, .friday:
            // 一趟遍历同算两个条件 目标=当日覆盖否则全局默认 与统计窗口径一致
            let def = AppConfig.shared.dailyGoalML
            let days = db.dayTotals()
            let ov = db.goalOverrides(dates: days.map { $0.date })
            let cal = Calendar.current
            var best = 0
            var fridays = 0
            for d in days {
                let goal = ov[d.date] ?? def
                guard goal > 0, d.ml > 0 else { continue }
                best = max(best, d.ml * 100 / goal)
                if let day = Database.dayFormat.date(from: d.date),
                   cal.component(.weekday, from: day) == 6, d.ml >= goal {
                    fridays += 1
                }
            }
            return kind == .overGoalDay ? best : fridays
        }
    }

    func earned(db: Database) -> Bool { currentValue(db: db) >= target }

    // 数字进度 current / target
    func progressText(_ cur: Int) -> String {
        let c = min(cur, target)
        switch kind {
        case .streak: return "\(c) / \(target) 天"
        case .cups: return "\(c.formatted()) / \(target.formatted()) 杯"
        case .volume: return "\(Self.lit(c)) / \(Self.lit(target)) L"
        case .firstLog: return c >= 1 ? "1 / 1" : "0 / 1"
        case .overGoalDay: return "单日最高 \(c)% · 目标 \(target)%"
        case .friday: return "\(min(cur, target)) / \(target) 次"
        }
    }

    // 距解锁还差的文案 头部勾引/详情卡共用 nil=已解锁
    func hint(_ cur: Int) -> String? {
        guard cur < target else { return nil }
        switch kind {
        case .streak: return "再坚持 \(target - cur) 天"
        case .cups: return "再喝 \((target - cur).formatted()) 杯"
        case .volume: return "再喝 \(Self.lit(target - cur)) L"
        case .firstLog: return "记下第一笔水"
        case .overGoalDay: return "单日再冲 \(max(1, target - cur))%"
        case .friday: return "挑一个周五达标"
        }
    }

    // ml转L文案 整数不带尾零 其余1位小数
    static func lit(_ ml: Int) -> String {
        let v = Double(ml) / 1000
        return v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

enum Achievements {
    // 奖牌渐变 与分享卡accentA→accentB同源
    static let medalGradient = LinearGradient(
        colors: [Color(hex: 0x53C2FF), Color(hex: 0x2F7BFF)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let all: [Badge] = [
        // 连续达标 今天没达标不算断(现有streak口径自带容错)
        Badge(id: "streak3", series: .streak, kind: .streak, name: "初来乍到", icon: "drop.fill",
              condition: "连续达标 3 天", target: 3),
        Badge(id: "streak7", series: .streak, kind: .streak, name: "一周不落", icon: "water.waves",
              condition: "连续达标 7 天", target: 7),
        Badge(id: "streak14", series: .streak, kind: .streak, name: "半月之约", icon: "cloud.rain.fill",
              condition: "连续达标 14 天", target: 14),
        Badge(id: "streak30", series: .streak, kind: .streak, name: "三十而立", icon: "hurricane",
              condition: "连续达标 30 天", target: 30),
        Badge(id: "streak100", series: .streak, kind: .streak, name: "百川归海", icon: "infinity",
              condition: "连续达标 100 天", target: 100),
        // 累计总量 喝过的每一滴都算数
        Badge(id: "vol10", series: .volume, kind: .volume, name: "细水长流", icon: "drop",
              condition: "累计喝水 10 L", target: 10_000),
        Badge(id: "vol50", series: .volume, kind: .volume, name: "潺潺成溪", icon: "shower.fill",
              condition: "累计喝水 50 L", target: 50_000),
        Badge(id: "vol100", series: .volume, kind: .volume, name: "汇流成河", icon: "sailboat.fill",
              condition: "累计喝水 100 L", target: 100_000),
        Badge(id: "vol500", series: .volume, kind: .volume, name: "大江大河", icon: "cloud.heavyrain.fill",
              condition: "累计喝水 500 L", target: 500_000),
        Badge(id: "vol1000", series: .volume, kind: .volume, name: "汪洋大海", icon: "fish.fill",
              condition: "累计喝水 1000 L", target: 1_000_000),
        // 累计杯数
        Badge(id: "cups1", series: .cups, kind: .cups, name: "第一杯", icon: "mug",
              condition: "记下第一杯水", target: 1),
        Badge(id: "cups100", series: .cups, kind: .cups, name: "百杯不怠", icon: "mug.fill",
              condition: "累计记 100 杯", target: 100),
        Badge(id: "cups1000", series: .cups, kind: .cups, name: "千杯不倦", icon: "star.circle.fill",
              condition: "累计记 1000 杯", target: 1_000),
        // 高光时刻 单日与彩蛋
        Badge(id: "first", series: .special, kind: .firstLog, name: "初次见面", icon: "hand.wave.fill",
              condition: "记下第一笔水", target: 1),
        Badge(id: "over150", series: .special, kind: .overGoalDay, name: "超额兑现", icon: "bolt.fill",
              condition: "单日喝到当日目标的 150%", target: 150),
        Badge(id: "friday", series: .special, kind: .friday, name: "周五战士", icon: "party.popper.fill",
              condition: "任意一个周五达标 1 次", target: 1),
    ]

    // 已解锁id集合 评估与建档共用
    static func earnedIDs(db: Database) -> Set<String> {
        Set(all.filter { $0.earned(db: db) }.map { $0.id })
    }
}
