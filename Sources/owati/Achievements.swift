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
    case rhythm    // 生活节奏 作息与口味
    case special   // 高光时刻 单日单次与彩蛋
    case mystery   // 秘藏 隐藏条件 达成后揭晓

    var title: String {
        switch self {
        case .streak: return "连续达标"
        case .volume: return "累计总量"
        case .cups: return "累计杯数"
        case .rhythm: return "生活节奏"
        case .special: return "高光时刻"
        case .mystery: return "秘藏"
        }
    }

    var icon: String {
        switch self {
        case .streak: return "calendar"
        case .volume: return "sum"      // 与统计窗"累计水合量"同源 免得和streak3水滴撞
        case .cups: return "number"
        case .rhythm: return "clock"
        case .special: return "sparkles"
        case .mystery: return "questionmark.square.dashed"
        }
    }
}

// 条件种类 决定当前值怎么算
enum BadgeKind {
    case streak       // 当前连续达标天数
    case volume       // 全库累计水合ml
    case cups         // 全库累计杯数
    case firstLog     // 记过第一笔 0/1
    case overGoalDay  // 历史单日最高达标率% 150/200两档
    case friday       // 达标过的周五次数
    case bigSip       // 单笔最大原始ml 500解锁
    case earlyBird    // 7点前记过一笔 0/1
    case nightOwl     // 23点后(含凌晨)记过一笔 0/1
    case taster       // 记过的饮品种类数 5解锁
    case coffee       // 咖啡累计杯数
    case perfectWeek  // 存在一个自然周七天全达标 0/1
    case daysCount    // 有记录的天数(不要求连续)
    case cupDay       // 历史单日最高杯数
    case monthChallenge // 本自然月达标天数 每月刷新
    case midnight     // 0点档(00:00-00:59)记过一笔 0/1
    case collector    // 其余全部徽章已收藏 动态目标
}

struct Badge: Identifiable {
    let id: String
    let series: BadgeSeries
    let kind: BadgeKind
    let name: String
    let icon: String      // 奖牌内SF图标
    let condition: String // 获取条件文案
    let target: Int       // volume单位ml 其余为天/杯/次/%
    var hidden: Bool = false // 秘藏 未解锁一律马赛克

    // 目标值 收藏家动态=除自己外的总数 其余用静态target
    var goal: Int {
        kind == .collector
            ? max(1, Achievements.all.filter { $0.kind != .collector }.count)
            : target
    }

    // 对外展示口径 未解锁的秘藏一律马赛克
    func displayIcon(got: Bool) -> String { hidden && !got ? "questionmark" : icon }

    // 贴纸emoji素材 一徽章一图案 多彩多样
    var stickerEmoji: String {
        switch id {
        case "streak3": return "🌦"
        case "streak7": return "☔"
        case "streak14": return "🌧"
        case "streak30": return "⛈"
        case "streak100": return "🌪"
        case "vol10": return "💧"
        case "vol50": return "🌊"
        case "vol100": return "⛵"
        case "vol500": return "🚢"
        case "vol1000": return "🐋"
        case "cups10": return "🥤"
        case "cups100": return "🍺"
        case "cups1000": return "👑"
        case "dawn": return "🌅"
        case "owl": return "🌙"
        case "taster": return "🎨"
        case "coffee": return "☕"
        case "oldfriend": return "❤️"
        case "first": return "👋"
        case "whale": return "🐳"
        case "buffalo": return "🐄"
        case "over150": return "⚡"
        case "friday": return "🏁"
        case "perfectweek": return "📅"
        case "monthly": return "🚩"
        case "midnight": return "🕛"
        case "tank": return "🛢"
        case "collector": return "🎖"
        // 新增40枚贴纸emoji
        case "streak2": return "🌤"
        case "streak5": return "☁️"
        case "streak10": return "🌥"
        case "streak20": return "🌬"
        case "streak21": return "❄️"
        case "streak40": return "🌨"
        case "streak50": return "🌫"
        case "streak60": return "💨"
        case "streak80": return "🌈"
        case "streak90": return "🌞"
        case "vol2000": return "🫗"
        case "vol5000": return "🚰"
        case "vol20000": return "🪣"
        case "vol30000": return "🍶"
        case "vol75000": return "🫙"
        case "vol200000": return "🛁"
        case "vol300000": return "🏊"
        case "vol750000": return "🚿"
        case "vol1500000": return "🦈"
        case "vol3000000": return "🐙"
        case "cups25": return "🧋"
        case "cups50": return "🍵"
        case "cups200": return "🍹"
        case "cups500": return "🍾"
        case "cups750": return "🍸"
        case "dawn3": return "🌄"
        case "dawn10": return "🌞"
        case "night3": return "🌙"
        case "taster8": return "🖌"
        case "coffee30": return "🥐"
        case "coffee50": return "🫖"
        case "days3": return "🌱"
        case "days7": return "🚶"
        case "days14": return "🌳"
        case "days60": return "🏡"
        case "days100": return "🏔"
        case "days200": return "🗺"
        case "bigSip1000": return "🫗"
        case "cupDay15": return "🧊"
        case "friday5": return "🎯"
        case "friday10": return "🏅"
        default: return "💧"
        }
    }
    func displayName(got: Bool) -> String { hidden && !got ? "？？？" : name }
    func displayCondition(got: Bool) -> String { hidden && !got ? "达成后揭晓" : condition }

    // 当前值 与target同口径 volume=ml overGoalDay=%
    func currentValue(db: Database) -> Int { currentValue(db.snapshot()) }

    // 快照版 一次快照全馆共用 不再每徽章各自查库
    func currentValue(_ snap: Database.Snapshot) -> Int {
        switch kind {
        case .streak: return snap.streak
        case .volume: return snap.totalAllML
        case .cups: return snap.totalCups
        case .firstLog: return min(snap.totalCups, 1)
        case .overGoalDay, .friday:
            // 一趟遍历同算两个条件 目标=当日覆盖否则全局默认 与统计窗口径一致
            let def = AppConfig.shared.dailyGoalML
            let cal = Calendar.current
            var best = 0
            var fridays = 0
            for d in snap.dayTotals {
                let goal = snap.goalOverrides[d.date] ?? def
                guard goal > 0, d.ml > 0 else { continue }
                best = max(best, d.ml * 100 / goal)
                if let day = Database.dayFormat.date(from: d.date),
                   cal.component(.weekday, from: day) == 6, d.ml >= goal {
                    fridays += 1
                }
            }
            return kind == .overGoalDay ? best : fridays
        case .bigSip: return snap.maxSingleML
        case .earlyBird: return min(snap.dawn, 1)
        case .nightOwl: return min(snap.night, 1)
        case .taster: return snap.typeCount
        case .coffee: return snap.cupsByType[DrinkType.coffee.rawValue, default: 0]
        case .perfectWeek:
            // 自然周内七天全达标 有记录日才算 空日不可能达标
            let def = AppConfig.shared.dailyGoalML
            let cal = Calendar.current
            var weekMet: [Date: Int] = [:]
            for d in snap.dayTotals {
                let goal = snap.goalOverrides[d.date] ?? def
                guard goal > 0, d.ml >= goal, let day = Database.dayFormat.date(from: d.date),
                      let wk = cal.dateInterval(of: .weekOfYear, for: day)?.start else { continue }
                weekMet[wk, default: 0] += 1
            }
            return weekMet.values.contains(7) ? 1 : 0
        case .daysCount: return snap.recordedDays
        case .cupDay: return snap.bestDayCups
        case .monthChallenge:
            // 本自然月达标天数 月切自动归零 只数当月
            let def = AppConfig.shared.dailyGoalML
            let monthPrefix = Database.dayFormat.string(from: Date()).prefix(7)
            var met = 0
            for d in snap.dayTotals where d.date.hasPrefix(monthPrefix) {
                let goal = snap.goalOverrides[d.date] ?? def
                if goal > 0, d.ml >= goal { met += 1 }
            }
            return met
        case .midnight: return min(snap.midnight, 1)
        case .collector:
            return Achievements.all.filter { $0.kind != .collector && $0.earned(snap) }.count
        }
    }

    func earned(db: Database) -> Bool { currentValue(db.snapshot()) >= goal }
    func earned(_ snap: Database.Snapshot) -> Bool { currentValue(snap) >= goal }

    // 数字进度 current / target
    func progressText(_ cur: Int) -> String {
        if hidden && cur < goal { return "？" }
        let c = min(cur, goal)
        switch kind {
        case .streak: return "\(c) / \(goal) 天"
        case .cups: return "\(c.formatted()) / \(goal.formatted()) 杯"
        case .volume: return "\(Self.lit(c)) / \(Self.lit(goal)) L"
        case .firstLog, .earlyBird, .nightOwl, .midnight: return c >= 1 ? "1 / 1" : "0 / 1"
        case .overGoalDay: return "单日最高 \(c)% · 目标 \(goal)%"
        case .friday: return "\(min(cur, goal)) / \(goal) 次"
        case .bigSip: return "\(c.formatted()) / \(goal.formatted()) ml"
        case .taster: return "\(c) / \(goal) 种"
        case .coffee: return "\(c.formatted()) / \(goal.formatted()) 杯"
        case .perfectWeek: return c >= 1 ? "1 / 1 周" : "0 / 1 周"
        case .daysCount: return "\(c) / \(goal) 天"
        case .cupDay: return "\(c) / \(goal) 杯"
        case .monthChallenge: return "\(c) / \(goal) 天"
        case .collector: return "\(c) / \(goal) 枚"
        }
    }

    // 距解锁还差的文案 头部勾引/详情卡共用 nil=已解锁
    func hint(_ cur: Int) -> String? {
        guard cur < goal else { return nil }
        if hidden { return "达成后揭晓" }
        switch kind {
        case .streak: return "再坚持 \(goal - cur) 天"
        case .cups: return "再喝 \((goal - cur).formatted()) 杯"
        case .volume: return "再喝 \(Self.lit(goal - cur)) L"
        case .firstLog: return "记下第一笔水"
        case .overGoalDay: return "单日再冲 \(max(1, goal - cur))%"
        case .friday: return "再战 \(goal - cur) 个周五"
        case .bigSip: return "单笔喝满 \(goal) ml"
        case .earlyBird: return "早起记一笔"
        case .nightOwl: return "深夜记一笔"
        case .taster: return "再解锁 \(goal - cur) 种饮品"
        case .coffee: return "再喝 \((goal - cur).formatted()) 杯咖啡"
        case .perfectWeek: return "一周七天全达标"
        case .daysCount: return "再陪 \(goal - cur) 天"
        case .cupDay: return "单日再喝 \(goal - cur) 杯"
        case .monthChallenge: return "本月再达标 \(goal - cur) 天"
        case .midnight: return "零点档来一杯"
        case .collector: return "还差 \(goal - cur) 枚"
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
        // 连续达标 雨势连续轴: 偶阵雨起步 细雨连绵 连雨 如注 风暴不息
        Badge(id: "streak3", series: .streak, kind: .streak, name: "初来乍到", icon: "cloud.sun.rain.fill",
              condition: "连续达标 3 天", target: 3),
        Badge(id: "streak7", series: .streak, kind: .streak, name: "一周不落", icon: "cloud.drizzle.fill",
              condition: "连续达标 7 天", target: 7),
        Badge(id: "streak14", series: .streak, kind: .streak, name: "半月之约", icon: "cloud.rain.fill",
              condition: "连续达标 14 天", target: 14),
        Badge(id: "streak30", series: .streak, kind: .streak, name: "三十而立", icon: "cloud.heavyrain.fill",
              condition: "连续达标 30 天", target: 30),
        Badge(id: "streak100", series: .streak, kind: .streak, name: "源远流长", icon: "hurricane",
              condition: "连续达标 100 天", target: 100),
        Badge(id: "streak2", series: .streak, kind: .streak, name: "小试身手", icon: "cloud.fill",
              condition: "连续达标 2 天", target: 2),
        Badge(id: "streak5", series: .streak, kind: .streak, name: "五日之约", icon: "cloud.fog.fill",
              condition: "连续达标 5 天", target: 5),
        Badge(id: "streak10", series: .streak, kind: .streak, name: "十日连珠", icon: "cloud.sleet.fill",
              condition: "连续达标 10 天", target: 10),
        Badge(id: "streak20", series: .streak, kind: .streak, name: "廿日不息", icon: "cloud.hail.fill",
              condition: "连续达标 20 天", target: 20),
        Badge(id: "streak21", series: .streak, kind: .streak, name: "习惯初成", icon: "cloud.snow.fill",
              condition: "连续达标 21 天", target: 21),
        Badge(id: "streak40", series: .streak, kind: .streak, name: "四十不惑", icon: "snowflake",
              condition: "连续达标 40 天", target: 40),
        Badge(id: "streak50", series: .streak, kind: .streak, name: "五十连绵", icon: "cloud.fog",
              condition: "连续达标 50 天", target: 50),
        Badge(id: "streak60", series: .streak, kind: .streak, name: "两月连绵", icon: "wind",
              condition: "连续达标 60 天", target: 60),
        Badge(id: "streak80", series: .streak, kind: .streak, name: "长跑渐入", icon: "cloud.rainbow.half",
              condition: "连续达标 80 天", target: 80),
        Badge(id: "streak90", series: .streak, kind: .streak, name: "九旬不断", icon: "sun.max.fill",
              condition: "连续达标 90 天", target: 90),
        // 累计总量 水量规模轴: 滴→溪波→泛舟→渡轮→海中之物 船的尺寸跟着水量长
        Badge(id: "vol10", series: .volume, kind: .volume, name: "细水长流", icon: "drop",
              condition: "累计喝水 10 L", target: 10_000),
        Badge(id: "vol50", series: .volume, kind: .volume, name: "潺潺成溪", icon: "water.waves",
              condition: "累计喝水 50 L", target: 50_000),
        Badge(id: "vol100", series: .volume, kind: .volume, name: "汇流成河", icon: "sailboat.fill",
              condition: "累计喝水 100 L", target: 100_000),
        Badge(id: "vol500", series: .volume, kind: .volume, name: "大江大河", icon: "ferry.fill",
              condition: "累计喝水 500 L", target: 500_000),
        Badge(id: "vol1000", series: .volume, kind: .volume, name: "汪洋大海", icon: "fish.fill",
              condition: "累计喝水 1000 L", target: 1_000_000),
        Badge(id: "vol2000", series: .volume, kind: .volume, name: "两升起步", icon: "drop.circle",
              condition: "累计喝水 2 L", target: 2_000),
        Badge(id: "vol5000", series: .volume, kind: .volume, name: "五升清泉", icon: "drop.circle.fill",
              condition: "累计喝水 5 L", target: 5_000),
        Badge(id: "vol20000", series: .volume, kind: .volume, name: "桶装满员", icon: "shippingbox.fill",
              condition: "累计喝水 20 L", target: 20_000),
        Badge(id: "vol30000", series: .volume, kind: .volume, name: "三十而饮", icon: "fork.knife",
              condition: "累计喝水 30 L", target: 30_000),
        Badge(id: "vol75000", series: .volume, kind: .volume, name: "七五之储", icon: "archivebox.fill",
              condition: "累计喝水 75 L", target: 75_000),
        Badge(id: "vol200000", series: .volume, kind: .volume, name: "两百升库", icon: "bathtub.fill",
              condition: "累计喝水 200 L", target: 200_000),
        Badge(id: "vol300000", series: .volume, kind: .volume, name: "三百升池", icon: "figure.pool.swim",
              condition: "累计喝水 300 L", target: 300_000),
        Badge(id: "vol750000", series: .volume, kind: .volume, name: "七百五十升", icon: "shower.fill",
              condition: "累计喝水 750 L", target: 750_000),
        Badge(id: "vol1500000", series: .volume, kind: .volume, name: "千五升海", icon: "fish.fill",
              condition: "累计喝水 1500 L", target: 1_500_000),
        Badge(id: "vol3000000", series: .volume, kind: .volume, name: "三千升洋", icon: "tortoise.fill",
              condition: "累计喝水 3000 L", target: 3_000_000),
        // 累计杯数 去掉与初次见面撞车的"第一杯" 10/100/1000
        Badge(id: "cups10", series: .cups, kind: .cups, name: "十杯之诺", icon: "mug",
              condition: "累计记 10 杯", target: 10),
        Badge(id: "cups100", series: .cups, kind: .cups, name: "百杯不怠", icon: "mug.fill",
              condition: "累计记 100 杯", target: 100),
        Badge(id: "cups1000", series: .cups, kind: .cups, name: "千杯不倦", icon: "crown.fill",
              condition: "累计记 1000 杯", target: 1_000),
        Badge(id: "cups25", series: .cups, kind: .cups, name: "廿五杯", icon: "cup.and.saucer",
              condition: "累计记 25 杯", target: 25),
        Badge(id: "cups50", series: .cups, kind: .cups, name: "半百杯", icon: "cup.and.saucer.fill",
              condition: "累计记 50 杯", target: 50),
        Badge(id: "cups200", series: .cups, kind: .cups, name: "两百杯", icon: "mug.fill",
              condition: "累计记 200 杯", target: 200),
        Badge(id: "cups500", series: .cups, kind: .cups, name: "五百杯", icon: "cup.and.saucer",
              condition: "累计记 500 杯", target: 500),
        Badge(id: "cups750", series: .cups, kind: .cups, name: "七百五十杯", icon: "mug",
              condition: "累计记 750 杯", target: 750),
        // 生活节奏 作息与口味彩蛋
        Badge(id: "dawn", series: .rhythm, kind: .earlyBird, name: "清晨第一滴", icon: "sun.horizon.fill",
              condition: "在早上 7 点前记过一笔", target: 1),
        Badge(id: "dawn3", series: .rhythm, kind: .earlyBird, name: "晨型选手", icon: "sunrise.fill",
              condition: "3 个清晨 7 点前记录", target: 3),
        Badge(id: "dawn10", series: .rhythm, kind: .earlyBird, name: "晨型大师", icon: "sun.and.horizon.fill",
              condition: "10 个清晨 7 点前记录", target: 10),
        Badge(id: "owl", series: .rhythm, kind: .nightOwl, name: "夜猫子补给", icon: "moon.stars.fill",
              condition: "在 23 点后记过一笔", target: 1),
        Badge(id: "night3", series: .rhythm, kind: .nightOwl, name: "深夜补给站", icon: "moon.circle.fill",
              condition: "3 个深夜 23 点后记录", target: 3),
        Badge(id: "taster", series: .rhythm, kind: .taster, name: "品鉴师", icon: "paintpalette.fill",
              condition: "集齐 5 种饮品记录", target: 5),
        Badge(id: "taster8", series: .rhythm, kind: .taster, name: "全类鉴赏家", icon: "paintbrush.fill",
              condition: "集齐 8 种饮品记录", target: 8),
        Badge(id: "coffee", series: .rhythm, kind: .coffee, name: "咖啡因账户", icon: "cup.and.saucer.fill",
              condition: "咖啡累计 10 杯", target: 10),
        Badge(id: "coffee30", series: .rhythm, kind: .coffee, name: "咖啡续命", icon: "flame.fill",
              condition: "咖啡累计 30 杯", target: 30),
        Badge(id: "coffee50", series: .rhythm, kind: .coffee, name: "咖啡自由", icon: "cup.and.saucer",
              condition: "咖啡累计 50 杯", target: 50),
        Badge(id: "oldfriend", series: .rhythm, kind: .daysCount, name: "老朋友", icon: "heart.fill",
              condition: "累计 30 天有记录", target: 30),
        Badge(id: "days3", series: .rhythm, kind: .daysCount, name: "三日相伴", icon: "leaf.fill",
              condition: "累计 3 天有记录", target: 3),
        Badge(id: "days7", series: .rhythm, kind: .daysCount, name: "一周同行", icon: "figure.walk",
              condition: "累计 7 天有记录", target: 7),
        Badge(id: "days14", series: .rhythm, kind: .daysCount, name: "两周相伴", icon: "tree.fill",
              condition: "累计 14 天有记录", target: 14),
        Badge(id: "days60", series: .rhythm, kind: .daysCount, name: "六十日久", icon: "house.fill",
              condition: "累计 60 天有记录", target: 60),
        Badge(id: "days100", series: .rhythm, kind: .daysCount, name: "百日之交", icon: "mountain.2.fill",
              condition: "累计 100 天有记录", target: 100),
        Badge(id: "days200", series: .rhythm, kind: .daysCount, name: "两百日盟", icon: "map.fill",
              condition: "累计 200 天有记录", target: 200),
        // 高光时刻 单次单日与彩蛋
        Badge(id: "first", series: .special, kind: .firstLog, name: "初次见面", icon: "hand.wave.fill",
              condition: "记下第一笔水", target: 1),
        Badge(id: "whale", series: .special, kind: .bigSip, name: "鲸饮", icon: "cloud.bolt.rain.fill",
              condition: "单笔喝下 500 ml", target: 500),
        Badge(id: "bigSip1000", series: .special, kind: .bigSip, name: "豪饮千毫升", icon: "water.waves.slash",
              condition: "单笔喝下 1000 ml", target: 1_000),
        Badge(id: "buffalo", series: .special, kind: .cupDay, name: "大水牛", icon: "10.circle.fill",
              condition: "单日喝满 10 杯", target: 10),
        Badge(id: "cupDay15", series: .special, kind: .cupDay, name: "十五杯之日", icon: "11.circle.fill",
              condition: "单日喝满 15 杯", target: 15),
        Badge(id: "over150", series: .special, kind: .overGoalDay, name: "马力全开", icon: "bolt.fill",
              condition: "单日喝到当日目标的 150%", target: 150),
        Badge(id: "friday", series: .special, kind: .friday, name: "周五战士", icon: "flag.checkered",
              condition: "在 3 个周五达标", target: 3),
        Badge(id: "friday5", series: .special, kind: .friday, name: "五周五战", icon: "flag.2.crossed.fill",
              condition: "在 5 个周五达标", target: 5),
        Badge(id: "friday10", series: .special, kind: .friday, name: "周五老将", icon: "rosette",
              condition: "在 10 个周五达标", target: 10),
        Badge(id: "perfectweek", series: .special, kind: .perfectWeek, name: "满勤周", icon: "calendar.badge.checkmark",
              condition: "一个自然周 7 天全达标", target: 1),
        // 限时挑战 每月刷新 当月清零重来
        Badge(id: "monthly", series: .special, kind: .monthChallenge, name: "满月之诺", icon: "flag.2.crossed.fill",
              condition: "本月达标 15 天", target: 15),
        // 秘藏 条件不公开 达成后揭晓
        Badge(id: "midnight", series: .mystery, kind: .midnight, name: "零点侠", icon: "0.circle.fill",
              condition: "在午夜零点档记过一笔", target: 1, hidden: true),
        Badge(id: "tank", series: .mystery, kind: .overGoalDay, name: "水箱本体", icon: "drop.circle.fill",
              condition: "单日喝到当日目标的 200%", target: 200, hidden: true),
        Badge(id: "collector", series: .mystery, kind: .collector, name: "收藏家", icon: "rosette",
              condition: "集齐陈列室全部徽章", target: 999),
    ]

    // 已解锁id集合 评估与建档共用
    static func earnedIDs(db: Database) -> Set<String> {
        let snap = db.snapshot()
        return Set(all.filter { $0.earned(snap) }.map { $0.id })
    }
}
