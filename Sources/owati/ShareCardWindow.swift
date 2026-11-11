import SwiftUI

// 今日成就卡片弹窗状态
final class ShareCardState: ObservableObject {
    @Published var cardImage: NSImage?
    // 卡片风格 0深 1浅 默认跟随系统外观
    @Published var cardMode = {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua ? 1 : 0
    }()
}

// 今日成就卡片弹窗 预览 + 复制/保存/分享
struct ShareCardWindowView: View {
    @ObservedObject var state = ShareCardState()

    var cardDate: Date { Date() }

    var body: some View {
        VStack(spacing: 16) {
            // 左月右日 点图标切风格 当前的亮蓝
            HStack(spacing: 28) {
                Button {
                    state.cardMode = 0
                } label: {
                    Image(systemName: "moon")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(state.cardMode == 0 ? Color.accentColor : fgSecondary)
                }
                .buttonStyle(.plain)
                Button {
                    state.cardMode = 1
                } label: {
                    Image(systemName: "sun.max")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(state.cardMode == 1 ? Color.accentColor : fgSecondary)
                }
                .buttonStyle(.plain)
            }
            // 卡片预览
            ShareCardView(date: cardDate, style: cardStyle)
                .frame(width: 340)
            // 操作条
            HStack(spacing: 10) {
                actionButton("复制", "doc.on.doc") { copyCard() }
                actionButton("保存", "arrow.down") { saveCard() }
                actionButton("分享", "square.and.arrow.up") { shareCard() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(windowBg.ignoresSafeArea())
        .onAppear {
            renderCard()
            syncWindowAppearance()
        }
        .onChange(of: state.cardMode) { _ in
            renderCard()
            syncWindowAppearance()
        }
    }

    // 随卡片风格的窗口配色
    private var windowBg: Color {
        state.cardMode == 1 ? .init(hex: 0xF4F8FF) : .init(hex: 0x0A1828)  // 浅 晨雾白 / 深 夜空黑
    }
    private var fgPrimary: Color {
        state.cardMode == 1 ? .init(hex: 0x16324F) : .white
    }
    private var fgSecondary: Color {
        state.cardMode == 1 ? Color.secondary : .white.opacity(0.6)
    }

    // 窗口标题栏外观跟风格走
    private func syncWindowAppearance() {
        let name: NSAppearance.Name = state.cardMode == 1 ? .aqua : .darkAqua
        NSApp.windows.first(where: { $0.title == "owati · 今日成就卡片" })?
            .appearance = NSAppearance(named: name)
    }

    private var cardStyle: ShareCardStyle {
        state.cardMode == 1 ? .light : .dark
    }

    // MARK: - 出图与动作
    // 把卡片渲染成图
    private func renderCard() {
        let renderer = ImageRenderer(content: ShareCardView(date: cardDate, style: cardStyle).frame(width: 340))
        renderer.scale = 2
        state.cardImage = renderer.nsImage
    }

    // 卡片PNG数据
    private func cardPNG() -> Data? {
        guard let img = state.cardImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    // 复制到剪贴板
    private func copyCard() {
        guard let img = state.cardImage else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([img])
    }

    // 保存PNG 保存面板选位置
    private func saveCard() {
        guard let png = cardPNG() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "owati-\(Database.dayFormat.string(from: cardDate)).png"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.begin { resp in
            if resp == .OK, let url = panel.url {
                try? png.write(to: url)
            }
        }
    }

    // 系统分享面板
    private func shareCard() {
        guard let img = state.cardImage else { return }
        let picker = NSSharingServicePicker(items: [img])
        if let view = NSApp.windows.first(where: { $0.title == "owati · 今日成就卡片" })?.contentView {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
    }

    // 操作按钮 配色跟窗口风格走
    private func actionButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(width: 96, height: 30)
            .foregroundColor(fgPrimary)
            .background(btnBg, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // 操作条按钮底色
    private var btnBg: Color {
        state.cardMode == 1 ? .black.opacity(0.05) : .white.opacity(0.1)
    }
}

// 今日成就卡片弹窗管理
enum ShareCardWindow {
    static var window: NSWindow?

    static func show() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            return
        }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 720),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.title = "owati · 今日成就卡片"
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: ShareCardWindowView())
        w.center()
        w.level = .floating
        window = w
        w.makeKeyAndOrderFront(nil)
    }
}
