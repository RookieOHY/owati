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
            // 关窗即暂停陈列室动画 一枚奖章一个15fps节拍改成全馆单节拍后再加这道闸
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: w, queue: .main) { _ in
                    Task { @MainActor in PanelState.shared.achvLive = false }
                }
        }
        if let w = window {
            if w.isMiniaturized { w.deminiaturize(nil) }
            // 临时转正 accessory的键盘焦点被系统吞 关窗切回accessory
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            PanelState.shared.openAchievementRoom()   // 快照新货 消底栏蓝点
            PanelState.shared.achvLive = true
            w.orderFrontRegardless()
            w.makeKeyAndOrderFront(nil)
        }
    }
}

// 陈列室 射灯下的悬浮奖章 一行6个展位 悬停揭幕看条件 点击出铭牌详情
struct AchievementView: View {
    @ObservedObject var state = PanelState.shared   // drinkPulse 记一笔立即重算
    @ObservedObject var cfg = AppConfig.shared      // 揭幕窗帘等配置
    let db = Database.shared

    var body: some View {
        let _ = state.drinkPulse   // 观察驱动 记一笔/删一笔都重算
        let earnedCount = Achievements.all.filter { $0.earned(db: db) }.count
        VStack(spacing: 12) {
            CapsuleTabs(titles: ["徽章", "贴纸"], index: state.achvTab) { state.achvTab = $0 }
                .padding(.top, 14)
            switch state.achvTab {
            case 1:
                StickerWall()
            default:
                // 馆牌与讲解屏钉在窗顶 滚到底也看得见
                header(earnedCount)
                    .padding(.top, 6)
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
        }
        .frame(width: 640)
        .overlay {
            if state.achvTab == 0, let id = state.achvDetailId,
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
        .lineLimit(1)
        .padding(.horizontal, 10)
        .frame(height: 36)
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
        // 分页 固定7个一页
        let pages = max(1, Int(ceil(Double(badges.count) / 7)))
        let page = min(max(0, state.seriesPage[s.title] ?? 0), pages - 1)
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
            // 展柜卡 分页式 固定7个一页 翻页代替滚动 右侧不再截半
            // 悬浮呼吸走CA直驱repeatForever 逐帧零CPU 关窗即静
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { slot in
                        Group {
                            if page * 7 + slot < badges.count {
                                showcaseCell(badges[page * 7 + slot], idx: page * 7 + slot)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                // 左右滑整行 翻页
                .gesture(
                    DragGesture(minimumDistance: 25)
                        .onEnded { g in
                            guard pages > 1 else { return }
                            if g.translation.width < -40, page < pages - 1 {
                                state.seriesPage[s.title] = page + 1
                            } else if g.translation.width > 40, page > 0 {
                                state.seriesPage[s.title] = page - 1
                            }
                        }
                )
                .overlay(alignment: .leading) {
                    if pages > 1 {
                        pageArrow("chevron.left", page > 0) { state.seriesPage[s.title] = page - 1 }
                            .padding(.leading, 2)
                    }
                }
                .overlay(alignment: .trailing) {
                    if pages > 1 {
                        pageArrow("chevron.right", page < pages - 1) { state.seriesPage[s.title] = page + 1 }
                            .padding(.trailing, 2)
                    }
                }
                // 页点 小圆点低调 不抢徽章的视觉 点击直达
                if pages > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<pages, id: \.self) { p in
                            Button {
                                state.seriesPage[s.title] = p
                            } label: {
                                Circle()
                                    .fill(p == page ? Color.owAccent : Color.primary.opacity(0.2))
                                    .frame(width: 6, height: 6)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // 分页箭头
    private func pageArrow(_ icon: String, _ enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(enabled ? .primary.opacity(0.6) : .primary.opacity(0.15))
                .frame(width: 18, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
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
                            if cfg.achvCurtain {
                                ZStack {
                                    // 两片同时从中间向左右缓缓拉开 无错开
                                    curtain(false)
                                        .offset(x: hovered ? -42 : 0)
                                        .opacity(hovered ? 0 : 1)
                                        .animation(.easeInOut(duration: 0.5), value: hovered)
                                    curtain(true)
                                        .offset(x: hovered ? 42 : 0)
                                        .opacity(hovered ? 0 : 1)
                                        .animation(.easeInOut(duration: 0.5), value: hovered)
                                }
                                .frame(width: 64, height: 66)
                            }
                        }
                        .frame(height: 46)
                }
            }
            .frame(height: 46)
            // 悬停只做幕布揭幕 不再放大徽章(放大导致整行鼓包)
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

    // 陈列台上的奖章悬浮 4秒一周期 相位按序号错开
    // 默认静帧: 展柜整窗重栅极贵(实测开着≈36%+) panelAnim开才播悬浮
    @ViewBuilder
    func floatingMedal(_ b: Badge, size: CGFloat, phase: Double) -> some View {
        if state.achvLive && AppConfig.shared.panelAnim {
            FloatLoop(live: true, phase: phase) {
                medallion(b, got: true, size: size, progress: 1)
            }
        } else {
            medallion(b, got: true, size: size, progress: 1)
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
                    // 已收藏徽章显示获得日 贴纸档案同源
                    if let date = cfg.badgeDates[b.id] {
                        Text("获得于 \(date)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.owAccent)
                    }
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




// MARK: 贴纸墙 展示墙+贴纸库 小宇宙同款
// 墙=陈列的贴纸(可拖拽) 库=全部收集(点切展示/收起) + 未获得的锁定剪影
struct StickerWall: View {
    @ObservedObject var state = PanelState.shared
    @ObservedObject var cfg = AppConfig.shared

    private let canvasW: CGFloat = 640
    private let canvasH: CGFloat = 520
    // 文字贴纸规格 徽章id -> (文本, 字体, 颜色) 多字体多色
    private let textSpecs: [String: (text: String, font: NSFont, color: NSColor)] = [
        "friday": ("周五冲！", safeFont("HanziPenSC-W3", 24), NSColor(red: 0.85, green: 0.2, blue: 0.3, alpha: 1)),
        "over150": ("马力全开", safeFont("PingFangSC-Semibold", 20), NSColor(red: 0.05, green: 0.42, blue: 0.92, alpha: 1)),
        "midnight": ("零点侠", safeFont("Menlo-Bold", 20), NSColor(red: 0.12, green: 0.3, blue: 0.6, alpha: 1)),
        "oldfriend": ("老朋友", safeFont("SnellRoundhand-Black", 22), NSColor(red: 0.8, green: 0.35, blue: 0.55, alpha: 1)),
    ]

    static func safeFont(_ name: String, _ size: CGFloat) -> NSFont {
        NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: .semibold)
    }

    // 刀版失败兜底 直接渲染内容
    private func plainImage(_ attr: NSAttributedString) -> NSImage {
        let sz = attr.size()
        let img = NSImage(size: sz)
        img.lockFocus()
        attr.draw(at: NSPoint.zero)
        img.unlockFocus()
        return img
    }

    var body: some View {
        let wall = wallStickers()
        let earned = earnedStickers()
        let locked = lockedStickers()
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    styleChips
                }
                .padding(.horizontal, 16)
                HStack {
                    Text("拖动贴纸 自由摆放 可重叠")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        cfg.stickerPos = [:]
                        state.stickerDragPos = [:]
                        state.stickerGrabs = [:]
                        cfg.stickerHidden = []
                    } label: {
                        Text("恢复默认")
                            .font(.system(size: 11))
                            .foregroundColor(.owAccent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                // 展示墙 只陈列未收起的贴纸
                ZStack {
                    boardBackground
                    if wall.isEmpty {
                        Text("从下方贴纸库选择要陈列的贴纸")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    ForEach(wall) { s in
                        Image(nsImage: stickerImage(s))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 132, height: 108)
                            .rotationEffect(.degrees(s.rot))
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            .overlay(alignment: .top) { stickerAccent(s) }
                            .position(pos(s))
                            .gesture(dragGesture(s))
                    }
                }
                .coordinateSpace(name: "stickerCanvas")
                .frame(height: canvasH)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                // 贴纸库栏 展开管理
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { state.stickerLibOpen.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 11, weight: .semibold))
                        Text("贴纸库(\(earned.count))")
                            .font(.system(size: 12, weight: .medium))
                        Text("未获得 \(locked.count)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                        Spacer()
                        Image(systemName: state.stickerLibOpen ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                // 贴纸库面板
                if state.stickerLibOpen {
                    VStack(alignment: .leading, spacing: 12) {
                        libSection(header: "已获得 · 点贴纸切换展示/收起", tiles: earned.map { .earned($0) })
                        if !locked.isEmpty {
                            libSection(header: "未获得 · 达成条件即可入袋", tiles: locked.map { .locked($0) })
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 12)
        }
    }

    // 库条目
    enum LibTile {
        case earned(WallSticker)
        case locked(Badge)
    }

    // 展示墙贴纸 = 已获得 减去收起
    private func wallStickers() -> [WallSticker] {
        earnedStickers().filter { !cfg.stickerHidden.contains($0.id) }
    }

    private func earnedStickers() -> [WallSticker] {
        let today = Database.dayFormat.string(from: Date())
        return cfg.badgeDates
            .compactMap { id, date -> WallSticker? in
                guard let b = Achievements.all.first(where: { $0.id == id }) else { return nil }
                return makeSticker(b: b, date: date.isEmpty ? today : date)
            }
            .sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }

    private func lockedStickers() -> [Badge] {
        Achievements.all.filter { cfg.badgeDates[$0.id] == nil }
    }

    // 组装单张贴纸 emoji款 或 多字体文字款 角度默认按id稳定散布
    private func makeSticker(b: Badge, date: String) -> WallSticker {
        let h = stableHash(b.id)
        let spec = textSpecs[b.id]
        return WallSticker(
            badge: b, date: date,
            emoji: spec == nil ? b.stickerEmoji : nil,
            text: spec?.text, font: spec?.font, color: spec?.color,
            rot: Double(h % 29) - 14,
            defPos: CGPoint(x: 60 + CGFloat(h % Int(canvasW - 230)),
                            y: 50 + CGFloat((h / 3) % Int(canvasH - 190))))
    }

    // 贴纸图 emoji刀版 或 文字刀版 缓存
    private func stickerImage(_ s: WallSticker) -> NSImage {
        let key = "\(s.id)-\(Int(canvasH))"
        if let c = Self.cache[key] { return c }
        let img: NSImage
        if let emoji = s.emoji {
            img = dieCutSticker(content: NSAttributedString(
                string: emoji, attributes: [.font: NSFont.systemFont(ofSize: 52)]),
                pad: 14)
                ?? plainImage(NSAttributedString(
                string: emoji, attributes: [.font: NSFont.systemFont(ofSize: 52)]))
        } else {
            img = dieCutSticker(content: NSAttributedString(
                string: s.text ?? "", attributes: [.font: s.font ?? NSFont.systemFont(ofSize: 20), .foregroundColor: s.color ?? .black]),
                pad: 12)
                ?? plainImage(NSAttributedString(
                string: s.text ?? "", attributes: [.font: s.font ?? NSFont.systemFont(ofSize: 20), .foregroundColor: s.color ?? .black]))
        }
        Self.cache[key] = img
        return img
    }

    static private var cache: [String: NSImage] = [:]

    // 刀版贴纸 CI形态学膨胀alpha涂白 原内容叠上
    private func dieCutSticker(content: NSAttributedString, pad: CGFloat) -> NSImage? {
        let lineH = ceil(content.size().height)
        let textW = ceil(content.size().width)
        let w = textW + pad * 2
        let h = lineH + pad * 2
        let base = NSImage(size: NSSize(width: w, height: h))
        base.lockFocus()
        content.draw(at: NSPoint(x: pad, y: (h - lineH) / 2))
        base.unlockFocus()
        guard let cg = base.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var ci = CIImage(cgImage: cg)
        guard let dilate = CIFilter(name: "CIMorphologyMaximum") else { return nil }
        dilate.setValue(ci, forKey: kCIInputImageKey)
        dilate.setValue(pad * 0.55, forKey: kCIInputRadiusKey)
        guard let dilated = dilate.outputImage else { return nil }
        // 膨胀轮廓涂白 RGB强制1 alpha保留
        let m = CIFilter(name: "CIColorMatrix")!
        m.setValue(dilated, forKey: kCIInputImageKey)
        m.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        m.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        m.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
        m.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        m.setValue(CIVector(x: 1, y: 1, z: 1, w: 0), forKey: "inputBiasVector")
        guard let white = m.outputImage else { return nil }
        let comp = CIFilter(name: "CISourceOverCompositing")!
        comp.setValue(ci, forKey: kCIInputImageKey)
        comp.setValue(white.cropped(to: ci.extent), forKey: kCIInputBackgroundImageKey)
        guard let out = comp.outputImage else { return nil }
        let rep = NSCIImageRep(ciImage: out.cropped(to: ci.extent))
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }

    // 稳定哈希 每次启动一致
    private func stableHash(_ s: String) -> Int {
        abs(s.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
    }

    // 已存位置优先 未存按id散布
    private func savedPos(_ s: WallSticker) -> CGPoint {
        if let saved = cfg.stickerPos[s.id] {
            let p = saved.split(separator: ",").compactMap { Double($0) }
            if p.count >= 2 { return CGPoint(x: p[0], y: p[1]) }
        }
        return s.defPos
    }

    private func pos(_ s: WallSticker) -> CGPoint {
        state.stickerDragPos[s.id] ?? savedPos(s)
    }

    private func rot(_ s: WallSticker) -> Double {
        if let saved = cfg.stickerPos[s.id] {
            let p = saved.split(separator: ",").compactMap { Double($0) }
            if p.count >= 3 { return p[2] }
        }
        return s.rot
    }

    // 拖拽 首帧记抓取偏移 跟手移动 松手持久化含角度
    private func dragGesture(_ s: WallSticker) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named("stickerCanvas"))
            .onChanged { g in
                let grab = state.stickerGrabs[s.id] ?? {
                    let off = CGSize(width: savedPos(s).x - g.location.x,
                                     height: savedPos(s).y - g.location.y)
                    state.stickerGrabs[s.id] = off
                    return off
                }()
                var p = CGPoint(x: g.location.x + grab.width, y: g.location.y + grab.height)
                p.x = min(max(p.x, 60), canvasW - 60)
                p.y = min(max(p.y, 60), canvasH - 60)
                var d = state.stickerDragPos
                d[s.id] = p
                state.stickerDragPos = d
            }
            .onEnded { g in
                let grab = state.stickerGrabs[s.id] ?? .zero
                var p = CGPoint(x: g.location.x + grab.width, y: g.location.y + grab.height)
                p.x = min(max(p.x, 60), canvasW - 60)
                p.y = min(max(p.y, 60), canvasH - 60)
                var saved = cfg.stickerPos
                saved[s.id] = "\(Int(p.x)),\(Int(p.y)),\(Int(rot(s)))"
                cfg.stickerPos = saved
                state.stickerGrabs[s.id] = nil
                var d = state.stickerDragPos
                d[s.id] = nil
                state.stickerDragPos = d
            }
    }

    // 库分区 已获得小片(点切换) 未获得锁定剪影
    private func libSection(header: String, tiles: [LibTile]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 10), count: 6), spacing: 10) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
                    libTile(tile)
                }
            }
        }
    }

    @ViewBuilder
    private func libTile(_ tile: LibTile) -> some View {
        switch tile {
        case .earned(let s):
            let hidden = cfg.stickerHidden.contains(s.id)
            Button {
                var h = cfg.stickerHidden
                if h.contains(s.id) { h.removeAll { $0 == s.id } } else { h.append(s.id) }
                cfg.stickerHidden = h
            } label: {
                VStack(spacing: 4) {
                    Image(nsImage: stickerImage(s))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 54)
                        .opacity(hidden ? 0.35 : 1)
                    Text(s.badge.name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(hidden ? .secondary : .primary)
                    Text(hidden ? "已收起" : "展示中")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(hidden ? .secondary : .owAccent)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .frame(width: 84)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(hidden ? 0.03 : 0.07)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(hidden ? "点一下放回墙上" : "点一下从墙上收起")
        case .locked(let b):
            // 普通徽章亮真实贴纸(变灰)+真名+条件 秘藏才问号遮面
            VStack(spacing: 4) {
                if b.hidden {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: "questionmark")
                            .font(.system(size: 14))
                            .foregroundColor(.primary.opacity(0.25))
                    }
                    Text("？？？")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(b.displayCondition(got: false))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.5))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(height: 20)
                } else {
                    Image(nsImage: stickerImage(makeSticker(b: b, date: "")))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 54)
                        .opacity(0.3)
                    Text(b.displayName(got: false))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(b.displayCondition(got: false))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.5))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(height: 20)
                }
            }
            .frame(width: 84)
        }
    }

    // 单张贴纸的完整描述
    struct WallSticker: Identifiable {
        var id: String { badge.id }
        let badge: Badge
        let date: String
        let emoji: String?
        let text: String?
        let font: NSFont?
        let color: NSColor?
        let rot: Double
        let defPos: CGPoint
    }
}

// MARK: 贴纸墙画板 四种样式 纯代码绘制 无图片资产
extension StickerWall {

    // 样式切换小胶囊
    var styleChips: some View {
        HStack(spacing: 4) {
            ForEach(Array(["点阵", "软木", "冰箱", "水纹"].enumerated()), id: \.offset) { i, t in
                Button {
                    cfg.wallStyle = i
                } label: {
                    Text(t)
                        .font(.system(size: 10, weight: cfg.wallStyle == i ? .semibold : .regular))
                        .foregroundColor(cfg.wallStyle == i ? .owAccent : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            cfg.wallStyle == i
                                ? AnyShapeStyle(Color.owAccent.opacity(0.14))
                                : AnyShapeStyle(Color.clear),
                            in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // 画板背景 按样式分发
    @ViewBuilder
    var boardBackground: some View {
        switch cfg.wallStyle {
        case 1: corkBoard
        case 2: fridgeDoor
        case 3: rippleBoard
        default: dotPaper
        }
    }

    // 点阵手账纸 纸底+淡点阵
    private var dotPaper: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Canvas { ctx, size in
                let spacing: CGFloat = 34
                var y = spacing
                while y < size.height {
                    var x = spacing
                    while x < size.width {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.8, height: 1.8)),
                                 with: .color(.primary.opacity(0.09)))
                        x += spacing
                    }
                    y += spacing
                }
            }
        }
    }

    // 软木板 颗粒斑点+深木框
    private var corkBoard: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xC49A5C), Color(hex: 0xA67C42)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                // 两种间距错相位的斑点 不让重复读成网格
                for (tile, r) in [(24.0, 1.4), (31.0, 1.0)] {
                    var y: CGFloat = 5
                    var row = 0
                    while y < size.height {
                        var x: CGFloat = row % 2 == 0 ? 4 : tile / 2
                        while x < size.width {
                            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                                     with: .color(.black.opacity(0.10)))
                            x += tile
                        }
                        y += tile / 2
                        row += 1
                    }
                }
            }
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(hex: 0x5C3D1E), lineWidth: 6)
        }
    }

    // 冰箱门 浅金属渐变+竖拉丝
    private var fridgeDoor: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.93), Color(white: 0.80)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                var x: CGFloat = 0.5
                while x < size.width {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                             with: .color(.black.opacity(0.035)))
                    x += 7
                }
            }
        }
    }

    // 水纹 纸底+同心涟漪 产品蓝
    private var rippleBoard: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Canvas { ctx, size in
                let c = CGPoint(x: size.width * 0.72, y: size.height * 0.38)
                for i in 1...6 {
                    let r = CGFloat(i) * 46
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.62, width: r * 2, height: r * 1.24)),
                        with: .color(Color.owAccent.opacity(max(0, 0.10 - Double(i) * 0.014))),
                        lineWidth: 1.2)
                }
            }
        }
    }

    // 贴纸上的画板装饰 点阵=和纸胶带压角 软木=图钉 其余无
    @ViewBuilder
    func stickerAccent(_ s: WallSticker) -> some View {
        let h = stableHash(s.id + "acc")
        switch cfg.wallStyle {
        case 0:
            // 和纸胶带 斜压贴纸上缘 半透明
            RoundedRectangle(cornerRadius: 1)
                .fill([Color.white.opacity(0.6), Color.teal.opacity(0.35), Color.pink.opacity(0.3)][h % 3])
                .frame(width: 34, height: 11)
                .rotationEffect(.degrees(Double(h % 14) - 7))
                .offset(y: -7)
                .shadow(color: .black.opacity(0.08), radius: 1, y: 0.5)
        case 1:
            // 图钉 红珠高光
            ZStack {
                Circle()
                    .fill(Color(hex: 0xC92A2A))
                    .frame(width: 9, height: 9)
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.85), Color(hex: 0xC92A2A)],
                                         center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 5))
                    .frame(width: 7, height: 7)
            }
            .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            .offset(y: -4)
        default:
            EmptyView()
        }
    }
}

// 悬浮循环效果 CA直驱: 开窗(achvLive翻转)触发一次 repeatForever由渲染服务接管 逐帧零CPU
// 不用@State宏(本环境不可用) live=false(窗关闭)时无动画 静止悬挂
struct FloatLoop<Content: View>: View {
    var live: Bool
    var phase: Double
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .offset(y: live ? -1.5 : 1.5)
            .animation(live ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
                                .delay((phase / (2 * .pi)) * 4.0) : nil, value: live)
    }
}
