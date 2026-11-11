import SwiftUI

// 分享卡两种风格
enum ShareCardStyle {
    case dark, light
}

// 分享卡配色 换肤只换Palette
struct ShareCardPalette {
    let bgTop: Color        // banner顶
    let bgMid: Color
    let bgThird: Color      // 过渡带
    let bgBody: Color       // 卡身
    let bgBottom: Color     // 卡底
    let primaryText: Color
    let secondaryText: Color
    let faintText: Color
    let accentA: Color      // 弧线渐变端1
    let accentB: Color      // 弧线渐变端2
    let accentSolid: Color
    let rowBg: Color
    let divider: Color
    let ringTrack: Color
    let dropOff: Color
    let dropOffText: Color
    let watermarkStrong: Color
    let watermarkSoft: Color
    let waveStrong: Color
    let waveSoft: Color
    let rowLabel: Color
    let footerStrong: Color
    let footerSoft: Color

    // 深色 夜空蓝
    static let dark = ShareCardPalette(
        bgTop: .init(hex: 0x4DA3FF), bgMid: .init(hex: 0x2F7BFF),
        bgThird: .init(hex: 0x1B3A66), bgBody: .init(hex: 0x0E1B2E), bgBottom: .init(hex: 0x091221),
        primaryText: .white, secondaryText: .white.opacity(0.55), faintText: .white.opacity(0.45),
        accentA: .init(hex: 0x53C2FF), accentB: .init(hex: 0x2F7BFF), accentSolid: .init(hex: 0x4DA3FF),
        rowBg: .white.opacity(0.06), divider: .white.opacity(0.08), ringTrack: .white.opacity(0.1),
        dropOff: .white.opacity(0.14), dropOffText: .white.opacity(0.45),
        watermarkStrong: .white.opacity(0.16), watermarkSoft: .white.opacity(0.12),
        waveStrong: .white.opacity(0.14), waveSoft: .white.opacity(0.10),
        rowLabel: .white.opacity(0.75), footerStrong: .white.opacity(0.35), footerSoft: .white.opacity(0.25)
    )

    // 浅色 晨光蓝
    static let light = ShareCardPalette(
        bgTop: .init(hex: 0x6FB1FF), bgMid: .init(hex: 0x9CC7FF),
        bgThird: .init(hex: 0xD9E9FF), bgBody: .init(hex: 0xF2F7FF), bgBottom: .init(hex: 0xFFFFFF),
        primaryText: .init(hex: 0x16324F), secondaryText: .init(hex: 0x5E7288), faintText: .init(hex: 0x8A9AB0),
        accentA: .init(hex: 0x53C2FF), accentB: .init(hex: 0x2F7BFF), accentSolid: .init(hex: 0x2F7BFF),
        rowBg: .black.opacity(0.04), divider: .black.opacity(0.08), ringTrack: .black.opacity(0.08),
        dropOff: .black.opacity(0.08), dropOffText: .init(hex: 0x5E7288),
        watermarkStrong: .white.opacity(0.3), watermarkSoft: .white.opacity(0.22),
        waveStrong: .white.opacity(0.4), waveSoft: .white.opacity(0.3),
        rowLabel: .init(hex: 0x3D5165), footerStrong: .black.opacity(0.35), footerSoft: .black.opacity(0.25)
    )
}

// 今日成就卡片 分享图主体 深浅两风格
struct ShareCardView: View {
    let date: Date
    var style: ShareCardStyle = .dark
    private var p: ShareCardPalette { style == .light ? .light : .dark }

    var body: some View {
        ZStack {
            // 整卡渐变打底
            RoundedRectangle(cornerRadius: 18)
                .fill(bgGradient)
            VStack(spacing: 0) {
                // banner装饰 波浪+水滴水印+品牌
                ZStack {
                    WaveShape(level: 0.80, phase: 1.5, amplitude: 5)
                        .fill(p.waveSoft)
                    WaveShape(level: 0.90, phase: 4.2, amplitude: 5)
                        .fill(p.waveStrong)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 72))
                        .foregroundColor(p.watermarkStrong)
                        .offset(x: 92, y: 8)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 32))
                        .foregroundColor(p.watermarkSoft)
                        .offset(x: -104, y: 16)
                    brandRow
                }
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                contentSection
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
            }
        }
    }

    // 品牌标
    private var brandRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "drop.fill")
                .font(.system(size: 16))
            Text("owati")
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
    }

    // 卡片背景渐变
    private var bgGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: p.bgTop, location: 0),
                .init(color: p.bgMid, location: 0.08),
                .init(color: p.bgThird, location: 0.18),
                .init(color: p.bgBody, location: 0.32),
                .init(color: p.bgBottom, location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    // 内容区 日期/环/状态句/数据列表/7天水滴/footer
    private var contentSection: some View {
        VStack(spacing: 18) {
            Text(Self.cardDayFormat.string(from: date))
                .font(.system(size: 12))
                .foregroundColor(p.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
            ringView
            statusView
            dataListView
            weekView
            footerView
        }
    }

    // 主视觉环
    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(p.ringTrack, style: StrokeStyle(lineWidth: 12))
            if progress >= 0.999 {
                Circle()
                    .stroke(
                        AngularGradient(colors: [p.accentA, p.accentB], center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: 12)
                    )
            } else {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [p.accentA, p.accentB], center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360 * progress)),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(totalML)")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundColor(p.primaryText)
                    Text("/ \(goal) ml")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(p.faintText)
                }
                Text("今日喝水量")
                    .font(.system(size: 11))
                    .foregroundColor(p.faintText)
            }
        }
        .frame(width: 176, height: 176)
    }

    // 状态句
    private var statusView: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.system(size: 13))
                .foregroundColor(p.accentSolid)
            Text(statusText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(p.primaryText)
        }
    }

    // 数据列表
    private var dataListView: some View {
        VStack(spacing: 0) {
            dataRow("今日喝水杯数", "\(cups) 杯", color: p.accentA)
            Divider().background(p.divider)
            dataRow("连续达标天数", "\(streak) 天", color: p.accentA)
            Divider().background(p.divider)
            dataRow("累计喝水总量", allTimeText, color: p.accentA)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(p.rowBg, in: RoundedRectangle(cornerRadius: 12))
    }

    // 最近7天 一天一颗水滴
    private var weekView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近 7 天喝水")
                .font(.system(size: 11))
                .foregroundColor(p.secondaryText)
            HStack(spacing: 6) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        ZStack {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 34))
                                .foregroundColor(item.isToday ? p.accentB : p.dropOff)
                            Text("\(item.cups)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(item.isToday ? .white : p.dropOffText)
                                .offset(y: 2)
                        }
                        Text("\(item.dayNum)")
                            .font(.system(size: 10))
                            .foregroundColor(item.isToday ? p.accentSolid : p.faintText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // footer
    private var footerView: some View {
        VStack(spacing: 3) {
            Text("owati")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(p.footerStrong)
            Text("喝水提醒")
                .font(.system(size: 9))
                .foregroundColor(p.footerSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    // 数据行 标签左 值右
    private func dataRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(p.rowLabel)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(color)
        }
        .padding(.vertical, 10)
    }

    // MARK: - 数据
    private let cal = Calendar.current
    private var dateStr: String { Database.dayFormat.string(from: date) }
    private var goal: Int { db.goalOverride(on: dateStr) ?? AppConfig.shared.dailyGoalML }
    private var totalML: Int { db.totalML(on: dateStr) }
    private var cups: Int { db.cups(on: dateStr) }
    private var progress: Double { min(Double(totalML) / Double(max(goal, 1)), 1.0) }
    private var streak: Int { db.streakDays(on: dateStr, goalML: goal) }
    private var allTimeML: Int { db.totalAllML() }

    private var allTimeText: String {
        allTimeML >= 1000 ? String(format: "%.1f L", Double(allTimeML) / 1000) : "\(allTimeML) ml"
    }

    // 状态句三态
    private var statusIcon: String {
        if cups == 0 { return "drop" }
        if totalML >= goal { return "checkmark.seal.fill" }
        return "figure.run"
    }
    private var statusText: String {
        if cups == 0 { return "来第一杯水，开启今天" }
        if totalML >= goal { return "今日目标已达成！" }
        return "离目标还差 \(goal - totalML) ml，继续加油"
    }

    // 最近7天 (卡片日期为终点) 杯数
    private var weekDays: [(cups: Int, dayNum: Int, isToday: Bool)] {
        let cal8601 = Calendar(identifier: .iso8601)
        let weekStart = cal8601.dateInterval(of: .weekOfYear, for: date)!.start
        return (0..<7).compactMap { i in
            guard let d = cal8601.date(byAdding: .day, value: i, to: weekStart) else { return nil }
            return (db.cups(on: Database.dayFormat.string(from: d)),
                    cal.component(.day, from: d),
                    cal.isDateInToday(d))
        }
    }

    private let db = Database.shared

    static let cardDayFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()
}

// 十六进制颜色便利
extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
