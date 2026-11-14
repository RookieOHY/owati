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
            PanelState.shared.openAchievementRoom()   // 快照新货 消底栏蓝点
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
        VStack(spacing: 12) {
            // 馆牌与讲解屏钉在窗顶 滚到底也看得见
            header(earnedCount)
                .padding(.top, 16)
                .padding(.horizontal, 16)
            infoStrip
                .padding(.horizontal, 16)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(BadgeSeries.allCases, id: \.self) { s in
                        seriesSection(s)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 8)
            }
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
        HStack(spacing: 8) {
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.system(size: 22))
                .foregroundStyle(Achievements.medalGradient)
            // hero式 已得大而蓝 总数小而灰
            (Text("已收藏 ")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            + Text("\(earned)")
                .font(.system(size: 26, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.owAccent)
            + Text(" / \(Achievements.all.count)")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(.secondary))
            Spacer()
        }
    }

    // 讲解屏 悬停展位=该藏品的条件与进度 空闲=最接近解锁的勾引提示
    // 信息固定在这条 不跟随展位浮卡 免得盖住展区标题
    var infoStrip: some View {
        let hovered = state.achvHoverId.flatMap { id in Achievements.all.first { $0.id == id } }
        return Group {
            if let b = hovered {
                let cur = b.currentValue(db: db)
                let got = cur >= b.goal
                HStack(spacing: 6) {
                    Image(systemName: b.displayIcon(got: got))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.owAccent)
                        // 定框 防sailboat/fish这类高个子符号把讲解屏撑高
                        .frame(width: 16, height: 16)
                    Text(b.displayName(got: got))
                        .fontWeight(.semibold)
                    Text(b.displayCondition(got: got))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(got ? "已收藏 ✓" : b.progressText(cur))
                        .monospacedDigit()
                        .fontWeight(got ? .semibold : .regular)
                        .foregroundColor(got ? .owAccent : .secondary)
                }
            } else if let hint = nextHint {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.owAccent)
                    Text(hint)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
    }

    // 最接近解锁的徽章 华为式进度外露 在头部勾一下 秘藏跳过不剧透
    var nextHint: String? {
        var bestBadge: Badge?
        var bestRatio = 0.0
        var bestCur = 0
        for b in Achievements.all {
            let cur = b.currentValue(db: db)
            guard cur < b.goal, !b.hidden else { continue }
            let r = Double(cur) / Double(b.goal)
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
            // 展区铭牌 比卡片小灰标题大一号 13pt
            HStack(spacing: 6) {
                Image(systemName: s.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.owAccent)
                Text(s.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                // hero式 已得大而蓝 总数小而灰 与馆牌同语言
                (Text("\(got)")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.owAccent)
                + Text(" / \(badges.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.secondary))
            }
            .padding(.leading, 10)
            // 展柜卡 一行通栏 每区一行 等分宽度整行填满自然居中
            HStack(spacing: 8) {
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
        let got = cur >= b.goal
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
                        .overlay(alignment: .topTrailing) {
                            // NEW角标 本次进馆还没看过的
                            if state.newBadgeIds.contains(b.id) {
                                Text("NEW")
                                    .font(.system(size: 7, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(Color.owAccent, in: Capsule())
                                    .overlay(Capsule().strokeBorder(.white.opacity(0.6)))
                                    .offset(x: 8, y: -4)
                            }
                        }
                } else {
                    medallion(b, got: false, size: 44,
                              progress: Double(cur) / Double(max(1, b.goal)))
                        .overlay {
                            ZStack {
                                curtain(false)
                                    .offset(x: hovered ? -34 : 0)
                                    .opacity(hovered ? 0 : 1)
                                curtain(true)
                                    .offset(x: hovered ? 34 : 0)
                                    .opacity(hovered ? 0 : 1)
                            }
                            .frame(width: 64, height: 66)
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
                    .fill(Color.primary.opacity(got ? 0.16 : 0.10))
                    .frame(width: 42, height: 7)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(got ? 0.09 : 0.06))
                    .frame(width: 54, height: 5)
            }
            Text(b.displayName(got: got))
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
            withAnimation(.easeOut(duration: 0.2)) {
                state.achvDetailId = b.id
                state.markAchvSeen(b.id)   // 看过详情 NEW即消
            }
        }
        .zIndex(hovered ? 3 : 1)
    }

    // 陈列台上的奖章悬浮呼吸 4秒一周期 相位按序号错开不开全齐步
    func floatingMedal(_ b: Badge, size: CGFloat, phase: Double) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate / 4.0 * 2 * .pi
            medallion(b, got: true, size: size, progress: 1)
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
    // 外圈进度环 锁定显示达成率蓝弧 满环=已收藏 progress传nil则不画环
    func medallion(_ b: Badge, got: Bool, size: CGFloat, progress: Double? = nil) -> some View {
        ZStack {
            Circle()
                .fill(got ? AnyShapeStyle(Achievements.medalGradient)
                          : AnyShapeStyle(Color.primary.opacity(0.10)))
                .frame(width: size, height: size)
            // 内圈细描边 提奖章质感
            Circle()
                .strokeBorder(got ? Color.white.opacity(0.35) : Color.primary.opacity(0.10),
                              lineWidth: 1)
                .frame(width: size - 6, height: size - 6)
            Image(systemName: b.displayIcon(got: got))
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(got ? .white : .primary.opacity(0.35))
        }
        .overlay {
            if let p = progress {
                let clamped = max(0, min(1, p))
                // 轨道 锁定才显 已收藏满环自身就是轨道
                if !got {
                    Circle()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 2.5)
                        .frame(width: size + 12, height: size + 12)
                }
                // 进度弧 从顶部中央顺时针
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(got ? AnyShapeStyle(Achievements.medalGradient)
                                : AnyShapeStyle(Color.owAccent),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size + 12, height: size + 12)
                    .animation(.easeOut(duration: 0.4), value: clamped)
            }
        }
    }

    // 讲解牌已改为顶部讲解屏 展位上不再浮卡
    // MARK: 藏品铭牌详情 非全屏浮层 点空白关闭

    func detailCard(_ b: Badge) -> some View {
        let cur = b.currentValue(db: db)
        let got = cur >= b.goal
        return ZStack {
            Color.primary.opacity(0.25)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeIn(duration: 0.15)) { state.achvDetailId = nil }
                }
            VStack(spacing: 12) {
                medallion(b, got: got, size: 68,
                          progress: got ? 1 : Double(cur) / Double(max(1, b.goal)))
                VStack(spacing: 4) {
                    Text(b.displayName(got: got))
                        .font(.system(size: 15, weight: .bold))
                    Text(b.displayCondition(got: got))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                VStack(spacing: 6) {
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
