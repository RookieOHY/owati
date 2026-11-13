import SwiftUI

// 成就陈列室 点底栏成就弹出 独立窗口 复用设置窗的浮动窗基类
// 尺寸对齐统计窗/设置窗(640宽) 陈列感: 射灯+悬浮徽章+展台+绒布遮罩
enum AchievementWindow {
    static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = FloatingPanelWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 680),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            w.title = "成就"
            w.isReleasedWhenClosed = false
            // 菜单栏app的普通窗口会被钉在别的空间 跟随当前空间+悬浮全屏应用上方
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            w.level = .floating
            w.setFrameAutosaveName("owatiAchievements")
            w.contentView = NSHostingView(rootView: AchievementView())
            window = w
        }
        if let w = window {
            if w.isMiniaturized { w.deminiaturize(nil) }
            // 临时转正 accessory的键盘焦点被系统吞 关窗切回accessory
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            w.orderFrontRegardless()
            w.makeKeyAndOrderFront(nil)
        }
    }
}

// 陈列室 射灯下的悬浮奖章 一行6个展位 悬停揭幕看条件 点击出铭牌详情
struct AchievementView: View {
    @ObservedObject var state = PanelState.shared   // drinkPulse 记一笔立即重算
    let db = Database.shared

    var body: some View {
        let _ = state.drinkPulse   // 观察驱动 记一笔/删一笔都重算
        let earnedCount = Achievements.all.filter { $0.earned(db: db) }.count
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                header(earnedCount)
                ForEach(BadgeSeries.allCases, id: \.self) { s in
                    seriesSection(s)
                }
            }
            .padding(16)
            // 底部留白 给最后一排的悬停tooltip
            .padding(.bottom, 44)
        }
        .frame(width: 640)
        .overlay {
            if let id = state.achvDetailId,
               let b = Achievements.all.first(where: { $0.id == id }) {
                detailCard(b)
            }
        }
        .animation(.easeOut(duration: 0.2), value: state.achvDetailId)
        .animation(.easeOut(duration: 0.2), value: state.achvHoverId)
    }

    // MARK: 馆牌 总览+勾引式提示

    func header(_ earned: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Achievements.medalGradient)
                Text("已收藏 \(earned) / \(Achievements.all.count)")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
            }
            if let hint = nextHint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // 最接近解锁的徽章 华为式进度外露 在头部勾一下
    var nextHint: String? {
        var bestBadge: Badge?
        var bestRatio = 0.0
        var bestCur = 0
        for b in Achievements.all {
            let cur = b.currentValue(db: db)
            guard cur < b.target else { continue }
            let r = Double(cur) / Double(b.target)
            if r > bestRatio { bestRatio = r; bestBadge = b; bestCur = cur }
        }
        guard let b = bestBadge, let h = b.hint(bestCur) else { return nil }
        return "\(h)，解锁「\(b.name)」"
    }

    // MARK: 展区

    func seriesSection(_ s: BadgeSeries) -> some View {
        let badges = Achievements.all.filter { $0.series == s }
        let got = badges.filter { $0.earned(db: db) }.count
        return VStack(alignment: .leading, spacing: 8) {
            // 展区铭牌 卡片小灰标题同款 缩进10
            HStack(spacing: 6) {
                Image(systemName: s.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.owAccent)
                Text(s.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(got) / \(badges.count)")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 10)
            // 展柜卡
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6),
                      spacing: 8) {
                ForEach(Array(badges.enumerated()), id: \.element.id) { i, b in
                    showcaseCell(b, idx: i)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: 展位

    func showcaseCell(_ b: Badge, idx: Int) -> some View {
        let cur = b.currentValue(db: db)
        let got = cur >= b.target
        let hovered = state.achvHoverId == b.id
        return VStack(spacing: 6) {
            // 射灯区 只有解锁的有光束
            Group {
                if got {
                    LightCone()
                        .fill(LinearGradient(colors: [Color.owAccent.opacity(0.22), Color.owAccent.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                        .blur(radius: 2.5)
                } else {
                    Color.clear
                }
            }
            .frame(width: 44, height: 30)
            // 展台上的藏品 解锁=悬浮呼吸 未解锁=剧院幕布拉开揭幕
            ZStack {
                if got {
                    floatingMedal(b, size: 46, phase: Double(idx) * 0.9)
                } else {
                    medallion(b, got: false, size: 44)
                        .overlay {
                            ZStack {
                                curtain(false)
                                    .offset(x: hovered ? -26 : 0)
                                    .opacity(hovered ? 0.05 : 1)
                                curtain(true)
                                    .offset(x: hovered ? 26 : 0)
                                    .opacity(hovered ? 0.05 : 1)
                            }
                            .frame(width: 54, height: 56)
                        }
                        .frame(height: 46)
                }
            }
            .frame(height: 46)
            .scaleEffect(hovered && got ? 1.06 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovered)
            // 底座 展台两级 台面下一点蓝光晕
            VStack(spacing: 2) {
                Ellipse()
                    .fill(got ? AnyShapeStyle(Color.owAccent.opacity(0.22)) : AnyShapeStyle(Color.clear))
                    .frame(width: 32, height: 5)
                    .blur(radius: 2)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(got ? 0.16 : 0.07))
                    .frame(width: 42, height: 7)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(got ? 0.09 : 0.04))
                    .frame(width: 54, height: 5)
            }
            Text(b.name)
                .font(.system(size: 10))
                .foregroundColor(got ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { h in
            state.achvHoverId = h ? b.id : (state.achvHoverId == b.id ? nil : state.achvHoverId)
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) { state.achvDetailId = b.id }
        }
        .overlay(alignment: .bottom) {
            if hovered {
                hoverTip(b, cur: cur, got: got)
            }
        }
        .zIndex(hovered ? 3 : 1)
    }

    // 陈列台上的奖章悬浮呼吸 4秒一周期 相位按序号错开不开全齐步
    func floatingMedal(_ b: Badge, size: CGFloat, phase: Double) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate / 4.0 * 2 * .pi
            medallion(b, got: true, size: size)
                .offset(y: 1.5 * sin(t + phase))
        }
    }

    // 一片剧院绒布 深夜蓝渐变+竖向褶皱纹 右片水平镜像
    func curtain(_ mirror: Bool) -> some View {
        let shape = CurtainHalf()
        return shape
            .fill(LinearGradient(colors: [Color(hex: 0x1B3A66), Color(hex: 0x10233F)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                // 褶皱纹 竖细条 用shape自身mask住不出布外
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.09))
                            .frame(width: 1.5)
                    }
                }
                .mask(shape)
            )
            .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            .scaleEffect(x: mirror ? -1 : 1)
    }

    // 奖章 统一圆底模板+主题图形 解锁=蓝渐变 锁定=灰剪影
    func medallion(_ b: Badge, got: Bool, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(got ? AnyShapeStyle(Achievements.medalGradient)
                          : AnyShapeStyle(Color.primary.opacity(0.07)))
                .frame(width: size, height: size)
            // 内圈细描边 提奖章质感
            Circle()
                .strokeBorder(got ? Color.white.opacity(0.35) : Color.primary.opacity(0.06),
                              lineWidth: 1)
                .frame(width: size - 6, height: size - 6)
            Image(systemName: b.icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(got ? .white : .primary.opacity(0.3))
        }
    }

    // 讲解牌 条件+数字进度 浮在展位下方
    func hoverTip(_ b: Badge, cur: Int, got: Bool) -> some View {
        VStack(spacing: 2) {
            Text(b.name)
                .fontWeight(.medium)
            Text(b.condition)
                .foregroundColor(.secondary)
            Text(got ? "已收藏 ✓" : b.progressText(cur))
                .fontWeight(got ? .semibold : .regular)
                .foregroundColor(got ? .owAccent : .secondary)
        }
        .font(.system(size: 10))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.1)))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .fixedSize()
        .offset(y: 58)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
        .zIndex(4)
    }

    // MARK: 藏品铭牌详情 非全屏浮层 点空白关闭

    func detailCard(_ b: Badge) -> some View {
        let cur = b.currentValue(db: db)
        let got = cur >= b.target
        return ZStack {
            Color.primary.opacity(0.25)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeIn(duration: 0.15)) { state.achvDetailId = nil }
                }
            VStack(spacing: 12) {
                medallion(b, got: got, size: 68)
                VStack(spacing: 4) {
                    Text(b.name)
                        .font(.system(size: 15, weight: .bold))
                    Text(b.condition)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                VStack(spacing: 6) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.1))
                            Capsule().fill(Color.owAccent)
                                .frame(width: g.size.width * (got ? 1 : min(1, Double(cur) / Double(b.target))))
                        }
                    }
                    .frame(height: 6)
                    Text(got ? "已收藏" : (b.hint(cur) ?? ""))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(got ? .owAccent : .secondary)
                    Text(b.progressText(cur))
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Button {
                    withAnimation(.easeIn(duration: 0.15)) { state.achvDetailId = nil }
                } label: {
                    Text("好")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 5)
                        .background(Color.owAccent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(width: 260)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.1)))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        }
        .transition(.opacity)
    }
}

// 射灯光束 顶部窄一条向下展开 梯形
struct LightCone: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX - 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// 剧院幕布左片 顶部横杆垂下 中缝在右 外沿在左 下摆三段波浪
// 右片由调用方水平镜像
struct CurtainHalf: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var p = Path()
        let hemY = rect.maxY - 6
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: hemY))
        // 从中缝走向外沿的波浪下摆
        let seg = rect.width / 3
        var x = rect.maxX
        for _ in 0..<3 {
            let nx = x - seg
            p.addQuadCurve(to: CGPoint(x: nx, y: hemY), control: CGPoint(x: x - seg / 2, y: hemY + 4))
            x = nx
        }
        p.closeSubpath()
        return p
    }
}

// MARK: 面板顶部解锁toast
extension PanelView {
    // 徽章解锁提示 浮在面板顶部 几秒自动收 多枚逐条排队
    var badgeToastCard: some View {
        HStack(spacing: 6) {
            Image(systemName: state.badgeToastIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Achievements.medalGradient)
            Text("解锁徽章 · \(state.badgeToastName)")
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
        .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(20)
    }
}
