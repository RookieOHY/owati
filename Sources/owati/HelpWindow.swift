import SwiftUI

// 帮助窗 转正期间Dock会亮图标 关窗切回accessory
final class HelpPanelWindow: NSWindow, NSWindowDelegate {
    override var canBecomeKey: Bool { true }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// 帮助窗口 点底栏帮助弹出 独立窗口
enum HelpWindow {
    static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = HelpPanelWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            w.delegate = w
            w.title = "帮助"
            w.isReleasedWhenClosed = false
            // 和设置窗同一套 指哪打哪 全屏应用上方也可见
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            w.level = .floating
            w.setFrameAutosaveName("owatiHelp")   // 记住位置
            w.contentView = NSHostingView(rootView: HelpView())
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

// 帮助页 单页文章流 HealthTick使用指南同构 分隔线分段 文字为主体
struct HelpView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                // 头部 logo + 标题 + 一句定位 居中
                HStack(spacing: 12) {
                    Spacer()
                    if let logo = PanelView.productLogo {
                        Image(nsImage: logo)
                            .resizable()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundColor(.owAccent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("owati 使用指南")
                            .font(.system(size: 20, weight: .bold))
                        Text("喝水记录 · 温和提醒 · 习惯养成")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Divider()
                guideFlow

                Divider()
                features

                Divider()
                statsGuide

                Divider()
                badgeGuide

                Divider()
                reminderRules

                Divider()
                tips

                Divider()
                faq

                Spacer(minLength: 16)
            }
            .padding(28)
        }
        .frame(minWidth: 640, minHeight: 620)
    }

    // 分区标题 彩色小图标+粗标题 HealthTick同款
    private func sectionTitle(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 14, weight: .bold))
        }
    }

    // MARK: 核心使用流程 四步讲一轮
    private var guideFlow: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("核心使用流程", icon: "arrow.triangle.2.circlepath", color: .blue)
            VStack(alignment: .leading, spacing: 12) {
                flowStep("1", "记一笔", "点开菜单栏水滴，点大圆环外圈任意位置即记一杯，杯量跟随快捷杯量；「一杯」「一瓶」一键记录；「自定义」里点击表情在 水→咖啡→茶→牛奶→果汁 间循环，输入毫升自动按水合系数换算。", color: .blue)
                flowStep("2", "看进度", "环下三列是杯数、连续达标天数、距上次喝水；本周水滴一天一滴，悬停看当天详情；状态行提示离目标还差多少。", color: .mint)
                flowStep("3", "被提醒", "提醒引擎常驻后台，按间隔排队，到点弹浮动卡片或全屏页面。记录一笔即从当下重新计时，刚喝完不会被马上催。", color: .orange)
                flowStep("4", "轻修正", "记错了点底部撤销条（6 秒内有效）；展开「今日详情」悬停某条可改量或删除；「今日目标」悬停显示数值，点击临时修改，只影响今天。", color: .purple)
            }
        }
    }

    // 数字步骤 彩色圆片+粗标题+说明
    private func flowStep(_ num: String, _ title: String, _ desc: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text(num)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: 功能速览 每个区域一行
    private var features: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("功能速览", icon: "slider.horizontal.3", color: .mint)
            VStack(alignment: .leading, spacing: 10) {
                featureItem("drop.fill", "大圆环", "今日进度的主体 点击外圈记一杯 环内直接显示已喝水量和目标。")
                featureItem("mug.fill", "一杯 / 一瓶", "按设置里的杯量、瓶量一键记录 记完有开罐音和撤销条。")
                featureItem("plus.circle", "自定义与水合系数", "水 100%、茶 95%、咖啡和牛奶 90%、果汁 85%，进度按换算后的毫升累计 输入时实时显示结果。")
                featureItem("chart.xyaxis.line", "三列数据", "今日杯数 / 连续达标天数 / 距上次喝水多久。")
                featureItem("calendar", "本周水滴", "周一开头 一天一滴 滴内是当天杯数 蓝色是今天。")
                featureItem("list.bullet.rectangle", "今日详情", "喝水时间线 两笔间隔2小时以上出现虚线标注 如实呈现没喝水的时段。")
                featureItem("drop", "剩余水量卡", "点击换单位 ml → L → 升 外圈是今日完成度。")
                featureItem("clock", "下次提醒卡", "点击在时刻和倒计时之间切换 外圈带时钟刻度和动点。")
                featureItem("calendar.badge.clock", "右上角日期", "点击循环显示 公历 → 农历 → 今天是不是周五。")
            }
        }
    }

    // 功能行 小图标+粗标题+一句说明
    private func featureItem(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.owAccent)
                .frame(width: 20, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: 统计 数据怎么看
    private var statsGuide: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("统计", icon: "chart.xyaxis.line", color: .pink)
            VStack(alignment: .leading, spacing: 10) {
                featureItem("clock.arrow.circlepath", "近7天 / 近30天",
                            "顶部胶囊切换 范围内所有指标随之重算。")
                featureItem("square.grid.2x2.fill", "指标卡阵",
                            "今日（当前/目标）、当前连续、历史最佳连续、累计水合量、范围内杯数、日均、达标率、单日最高 八张卡 悬停会浮起 带问号的行有详细口径说明。")
                featureItem("chart.bar.fill", "柱状图与饮品构成",
                            "每天一根柱子 达标日高亮；下方是各饮品类型的构成占比。")
                featureItem("sum", "水合量口径",
                            "统计和进度环同一口径：水 ×1.0、茶 ×0.95、咖啡和牛奶 ×0.9、果汁 ×0.85——250ml 咖啡记 225。")
            }
        }
    }

    // MARK: 成就 徽章怎么玩
    private var badgeGuide: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("成就", icon: "trophy.fill", color: .yellow)
            VStack(alignment: .leading, spacing: 10) {
                featureItem("arrow.triangle.2.circlepath", "实时计算",
                            "徽章条件全部从喝水记录实时算 没有解锁存档——撤销、改量后进度自动回退，靠数据说话。")
                featureItem("medal.fill", "六大系列",
                            "连续达标 / 累计总量 / 累计杯数 / 生活节奏 / 高光时刻 / 秘藏 未解锁的点开能看条件 达标自动点亮。")
                featureItem("questionmark.square.dashed", "秘藏徽章",
                            "隐藏条件的彩蛋 未解锁一律马赛克 达成后揭晓；「收藏家」的目标是集齐其余全部徽章 动态计数。")
                featureItem("smallcircle.filled.circle.fill", "新徽章红点",
                            "解锁新徽章后 底栏成就按钮亮红点 进成就页看完即消。")
            }
        }
    }

    // MARK: 提醒机制 规则块+例子 每条独立成行
    private var reminderRules: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("提醒机制", icon: "bell.fill", color: .orange)
            VStack(alignment: .leading, spacing: 16) {
                ruleItem("timer", "常驻引擎",
                         "提醒引擎随进程常驻，面板开不开都在跑。按设置的间隔排队，到点按设定的载体弹出——浮动卡片或全屏页面。记录一笔、调整节奏后，都从当下重新计时。",
                         example: "例：间隔 45 分钟，15:00 记了一杯 → 下一次提醒排在 15:45，刚喝完不会被马上催。")
                ruleItem("calendar.badge.checkmark", "四道静默闸门",
                         "到点先过闸，任一命中就顺延、不打扰：① 不在提醒时间段或提醒日 ② 处于勿扰时段（如午休）③ 会议应用在前台 ④ 人离开了。",
                         example: "例：提醒时段 09:00–19:00，19:30 才到点 → 顺延到明早；15:00 到点时 Zoom 正在前台 → 推迟 2 分钟，15:02 再看一眼。")
                ruleItem("moon.zzz.fill", "人离开会补提醒",
                         "5 分钟没有键鼠活动视为离开，本轮静默滑过；人回来后主动补一次，防止离开期间错过整段补水。",
                         example: "例：14:00 到点时你已离开半小时 → 不弹；15:20 手一回来 → 「回来啦 先喝杯水」。")
                ruleItem("gauge", "达标后节奏放缓",
                         "达到今日目标后，提醒间隔按设置的倍数放缓（×1 / ×2 / ×3），全屏提醒自动降级为小卡片，文案换成保持款。",
                         example: "例：间隔 45 分钟、节奏 ×2，18:00 达标 → 下一次排在 19:30 而不是 18:45。")
                ruleItem("pause.circle", "超额静音",
                         "今日饮水超过目标的设定比例后，当天彻底安静——喝水过量同样无益，第二天自动恢复。",
                         example: "例：目标 2000ml、超额静音 150% → 喝到 3000ml 后今天不再提醒。")
                ruleItem("flag", "跳过会被记住",
                         "点「稍后」、提醒放超时都算跳过。连续跳过达到阈值、且期间没有新记录时，文案换成催促款——温和升级；记录一笔即清零。",
                         example: "例：连跳 2 次 → 下一次文案从「小口慢饮 更利吸收」换成「已经连续跳过啦 身体在等水」。")
            }
            Text("以上闸门和节奏在 设置 里都能调，每行后面的问号有单项说明。")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
        }
    }

    // 规则块 图标+粗标题+说明+例子 例子独立一行浅色
    private func ruleItem(_ icon: String, _ title: String, _ body: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.owAccent)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            Text(body)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(example)
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.72))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 24)
        }
    }

    // MARK: 使用建议 圆点列表
    private var tips: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("使用建议", icon: "lightbulb.fill", color: .yellow)
            VStack(alignment: .leading, spacing: 8) {
                tipItem("每日目标 1500–2500ml 起步，按体重和活动量微调，别一步到位设太高。")
                tipItem("杯量按自己常用的杯子设——记录按钮越贴近现实，越容易坚持。")
                tipItem("勿扰时段设成午休，提醒会自动避开；开会多就保持会议暂停开启。")
                tipItem("沉浸工作时选全屏提醒，并搭配催促阈值，让提醒「硬」一点。")
                tipItem("数据只存本机 ~/Library/Application Support/owati/data.db，不联网不上传。")
            }
        }
    }

    // 建议条 圆点+文字
    private func tipItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(Color.owAccent)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 常见问题 答案先行
    private var faq: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("常见问题", icon: "questionmark.circle.fill", color: .purple)
            VStack(alignment: .leading, spacing: 12) {
                faqRow("为什么没提醒我？",
                       "按引擎的实际判定顺序挨个检查：① 现在在提醒时间段内吗 ② 今天是提醒日吗 ③ 在勿扰时间段里吗 ④ 今天已达标（节奏放缓或超额静音生效）⑤ 会议应用在前台 ⑥ 人刚离开。都在正常范围就等下一轮。")
                faqRow("为什么提醒变慢了？",
                       "三种情况会放慢：达到目标后按倍数放缓、超额静音生效后当天安静、会议应用在前台时推迟2分钟。都是设计行为不是故障。")
                faqRow("记错了怎么办？",
                       "刚记错点底部撤销条，6 秒内有效；过了撤销窗口就展开「今日详情」，悬停那条记录直接改毫升或删除。")
                faqRow("临时改的今日目标会影响明天吗？",
                       "不会，只覆盖今天这一天，第二天自动回到设置里的全局目标。")
                faqRow("开机自启动不生效？",
                       "未打包的开发版可执行文件注册不了系统服务，打包成 app 后就正常了。")
            }
        }
    }

    // 问答行 加粗问题+答案正文
    private func faqRow(_ q: String, _ a: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(q)
                .font(.system(size: 13, weight: .bold))
            Text(a)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
