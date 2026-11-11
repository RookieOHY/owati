import SwiftUI

// 圆形进度 外圈弧线 里头装波浪
struct WaveRing: View {
    var progress: Double
    var consumedML: Double
    var goalML: Int
    var celebrate: Bool = false

    // 空态也留一点水位 "还没喝"也有画面
    private var waterLevel: Double { max(progress, 0.06) }
    private var isEmpty: Bool { progress <= 0.001 }

    var body: some View {
        ZStack {
            // 圆内底色 亮暗外观都衬文字
            Circle().fill(.primary.opacity(0.05))
            // 外圈进度弧
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.08), style: StrokeStyle(lineWidth: 6))
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [.cyan, .blue, .indigo], center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360 * progress)),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90)) // 从正上方起笔
                // 顶部高光 玻璃感
                Circle()
                    .trim(from: 0.01, to: 0.24)
                    .stroke(
                        AngularGradient(colors: [.white.opacity(0.02), .white.opacity(0.3), .white.opacity(0.02)],
                                        center: .center, startAngle: .degrees(-80), endAngle: .degrees(-20)),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
            }
            .padding(3)
            // 波浪 双层 一深一浅错开动 相位累加 庆祝时奔腾
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                let p = PanelState.shared.advanceWave(now: ctx.date, celebrate: celebrate)
                ZStack {
                    WaveShape(level: waterLevel, phase: p + 1.3, amplitude: 4)
                        .fill(.cyan.opacity(0.3))
                    WaveShape(level: waterLevel, phase: p * 1.41 + 3.8, amplitude: 5.5)
                        .fill(LinearGradient(colors: [.blue.opacity(0.7), .cyan.opacity(0.85)],
                                             startPoint: .top, endPoint: .bottom))
                }
                .animation(.spring(duration: 0.9, bounce: 0.25), value: progress)
            }
            .clipShape(Circle())
            .padding(6)
            // 中央 百分比 + 喝了多少 空态数字弱化
            VStack(spacing: 3) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundColor(isEmpty ? .primary.opacity(0.35) : .primary)
                    .scaleEffect(celebrate ? 1.12 : 1)
                    .animation(.spring(duration: 0.45, bounce: 0.5), value: celebrate)
                Text("\(Int(consumedML)) / \(goalML) ml")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .opacity(0.7)
            }
        }
        .frame(width: 120, height: 120)
        // 达标微弹 整环轻弹一下
        .scaleEffect(celebrate ? 1.05 : 1)
        .animation(.spring(duration: 0.45, bounce: 0.45), value: celebrate)
    }
}

// 正弦水面 线以下填满
struct WaveShape: Shape {
    var level: Double     // 0 底 1 顶
    var phase: Double
    var amplitude: CGFloat

    nonisolated var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    nonisolated func path(in rect: CGRect) -> Path {
        let baseline = rect.maxY - rect.height * level
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: baseline))
        // 沿正弦走 每隔4pt取一点
        let steps = max(8, Int(rect.width / 4))
        for s in 0...steps {
            let x = rect.minX + rect.width * CGFloat(s) / CGFloat(steps)
            let y = baseline + amplitude * sin(x / rect.width * 2 * .pi * 1.5 + phase)
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
