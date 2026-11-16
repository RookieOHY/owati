import AppKit
import SwiftUI
import Foundation

// MARK: 应用自更新 检查/下载/安装
// 发布物: GitHub Releases 的 owati-<版本>-<架构>.dmg (package.sh+Actions产出)

let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
let updaterRepo = "RookieOHY/owati"

// 自证架构: 读自身可执行的Mach-O头cputype(64位魔数0xfeedfacf 0x0100000C=arm64 0x01000007=x86_64)
// 自己是什么架构就只能装什么架构的更新
var machineArch: String {
    if let exe = Bundle.main.executableURL,
       let handle = try? FileHandle(forReadingFrom: exe) {
        let header = (try? handle.read(upToCount: 8)) ?? Data()
        try? handle.close()
        if header.count >= 8 {
            let magic = header.withUnsafeBytes { $0.load(as: UInt32.self) }
            let cpu = header.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
            if magic == 0xfeedfacf {
                if cpu == 0x0100000C { return "aarch64" }
                if cpu == 0x01000007 { return "x86_64" }
            }
        }
    }
    // 头读不到时退回uname
    var sysinfo = utsname()
    uname(&sysinfo)
    let machine = withUnsafePointer(to: &sysinfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
    return machine.hasPrefix("arm64") ? "aarch64" : "x86_64"
}

// 多段版本号比较 v0.1.4 > v0.1.3 按段数值比
func isNewerVersion(_ remote: String, than local: String) -> Bool {
    let r = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        .split(separator: ".").compactMap { Int($0) }
    let l = local.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        .split(separator: ".").compactMap { Int($0) }
    for i in 0..<max(r.count, l.count) {
        let rv = i < r.count ? r[i] : 0
        let lv = i < l.count ? l[i] : 0
        if rv != lv { return rv > lv }
    }
    return false
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var hasUpdate = false
    @Published var latestVersion: String?
    @Published var releaseNotes: String?
    @Published var isChecking = false
    @Published var checkError: String?
    // 下载状态
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var downloadDone = false
    @Published var downloadedFileURL: URL?
    @Published var isInstalling = false

    private var downloadTask: URLSessionDownloadTask?
    private var downloadDelegate: UpdateDownloadDelegate?
    private var downloadSession: URLSession?

    // MARK: 检查

    func check() {
        guard !isChecking else { return }
        isChecking = true
        checkError = nil
        PanelState.shared.updateStatus = "检查中…"
        Task {
            await checkForUpdates()
            isChecking = false
        }
    }

    private func checkForUpdates() async {
        // 系统网络优先 出口IP被限流(403)或失败时绕代理直连 最后退到Atom订阅源
        var tag: String?
        var notes = ""
        var assetSize: Int64 = 0

        if let r = await fetchViaAPI(bypassProxy: false) {
            tag = r.tag; notes = r.notes; assetSize = r.size
        } else if let r = await fetchViaAPI(bypassProxy: true) {
            tag = r.tag; notes = r.notes; assetSize = r.size
        } else if let r = await fetchViaAtom() {
            tag = r
        }

        guard let tag else {
            PanelState.shared.updateStatus = "暂时检查不了 稍后再试"
            checkError = "GitHub接口连不上(代理出口IP可能被限流)"
            return
        }
        latestVersion = tag
        releaseNotes = notes
        totalBytes = assetSize

        // 与本地版本比对
        if isNewerVersion(tag, than: appVersion) {
            hasUpdate = true
            PanelState.shared.updateStatus = "发现新版本 \(tag) 在更新窗口下载"
            UpdateWindow.show()
        } else {
            hasUpdate = false
            PanelState.shared.updateStatus = "已是最新版本 \(tag)"
        }
    }

    // API返回(tag,说明,安装包体积) 三元组 任一环失败即nil 交由下一路兜底
    private func fetchViaAPI(bypassProxy: Bool) async -> (tag: String, notes: String, size: Int64)? {
        guard let url = URL(string: "https://api.github.com/repos/\(updaterRepo)/releases/latest") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let cfg = URLSessionConfiguration.ephemeral
        if bypassProxy { cfg.connectionProxyDictionary = [:] }
        let session = URLSession(configuration: cfg)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, resp) = try? await session.data(for: request),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String else { return nil }
        let notes = obj["body"] as? String ?? ""
        // 架构匹配的安装包资产 tag自带v 资产名不带
        var size: Int64 = 0
        let verClean = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let dmgName = "owati-\(verClean)-\(machineArch).dmg"
        if let assets = obj["assets"] as? [[String: Any]],
           let asset = assets.first(where: { ($0["name"] as? String) == dmgName }) {
            size = (asset["size"] as? Int64) ?? Int64(asset["size"] as? Int ?? 0)
        }
        if size == 0 { return nil } // 资产还没传齐 视同此路不通
        return (tag, notes, size)
    }

    // Atom订阅源 走github.com域名 不占api.github.com的IP限流额度
    private func fetchViaAtom() async -> String? {
        guard let url = URL(string: "https://github.com/\(updaterRepo)/releases.atom") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, resp) = try? await session.data(for: request),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let xml = String(data: data, encoding: .utf8) else { return nil }
        // 第一个entry即最新版 id末段就是tag 如 tag:github.com,2008:Repository/xxx/v0.1.4
        for chunk in xml.components(separatedBy: "<entry>").dropFirst() {
            guard let afterId = chunk.components(separatedBy: "<id>")[1...].first,
                  let id = afterId.components(separatedBy: "</id>").first else { continue }
            if let last = id.components(separatedBy: "/").last, last.hasPrefix("v") {
                return last
            }
        }
        return nil
    }

    // MARK: 下载

    func downloadUpdate() {
        guard hasUpdate, let rawVer = latestVersion, !isDownloading else { return }
        // tag自带v 去掉再拼资产名与下载路径
        let ver = rawVer.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard !ver.isEmpty else { return }
        let dmgName = "owati-\(ver)-\(machineArch).dmg"
        guard let url = URL(string: "https://github.com/\(updaterRepo)/releases/download/v\(ver)/\(dmgName)") else { return }
        guard totalBytes > 0 else {
            PanelState.shared.updateStatus = "安装包还没发布好 稍后再试"
            return
        }
        isDownloading = true
        downloadDone = false
        downloadProgress = 0

        let delegate = UpdateDownloadDelegate(
            expectedSize: totalBytes,
            onProgress: { [weak self] progress, received, total in
                Task { @MainActor in
                    self?.downloadProgress = progress
                    self?.downloadedBytes = received
                    if total > 0 { self?.totalBytes = total }
                }
            },
            onComplete: { [weak self] fileURL in
                Task { @MainActor in
                    self?.downloadSession?.finishTasksAndInvalidate()
                    self?.downloadSession = nil
                    self?.isDownloading = false
                    self?.downloadDone = true
                    self?.downloadedFileURL = fileURL
                }
            },
            onError: { [weak self] message in
                Task { @MainActor in
                    self?.downloadSession?.invalidateAndCancel()
                    self?.downloadSession = nil
                    self?.isDownloading = false
                    self?.checkError = "下载失败：\(message)"
                    PanelState.shared.updateStatus = "下载失败 可从 GitHub Releases 手动下载"
                }
            }
        )
        downloadDelegate = delegate
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        downloadSession = session
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadSession?.invalidateAndCancel()
        downloadSession = nil
        downloadDelegate = nil
        isDownloading = false
        downloadProgress = 0
        downloadDone = false
    }

    // MARK: 安装

    // 独立bash进程完成替换 本体立即退场 由脚本拉起新版
    func installAndRestart() {
        guard downloadDone, let fileURL = downloadedFileURL else { return }
        let destApp = Bundle.main.bundlePath
        // 裸可执行(开发态)没有.app结构 无法自动替换 引导手动下载
        guard destApp.hasSuffix(".app") else {
            PanelState.shared.updateStatus = "开发环境不支持自动安装 请手动下载安装"
            if let u = URL(string: "https://github.com/\(updaterRepo)/releases/latest") {
                NSWorkspace.shared.open(u)
            }
            return
        }
        // 安装包架构必须和本机一致 跑不起来的包绝不能替换掉能跑的
        let wantArch = machineArch == "aarch64" ? "arm64" : "x86_64"
        isInstalling = true

        let script = """
        #!/bin/bash
        DMG_PATH="\(fileURL.path)"
        DEST_APP="\(destApp)"

        MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse -noverify 2>/dev/null | grep -o '/Volumes/[^\t]*' | head -1)

        if [ -z "$MOUNT_POINT" ]; then
            open "$DMG_PATH"
            exit 1
        fi

        SOURCE_APP="$MOUNT_POINT/owati.app"

        if [ ! -d "$SOURCE_APP" ]; then
            hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
            open "$DMG_PATH"
            exit 1
        fi

        # 架构校验 不含本机架构就放弃自动替换 改开DMG手动处理
        if ! /usr/bin/lipo -archs "$SOURCE_APP/Contents/MacOS/owati" 2>/dev/null | /usr/bin/grep -qw "\(wantArch)"; then
            hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
            open "$DMG_PATH"
            exit 1
        fi

        sleep 2

        rm -rf "$DEST_APP"
        cp -R "$SOURCE_APP" "$DEST_APP"
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
        open "$DEST_APP"
        rm -f "$0"
        """

        do {
            let scriptPath = NSTemporaryDirectory() + "owati_update.sh"
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath]
            try process.run()

            // 本体马上退场 脚本sleep后替换并启动新版
            NSApp.terminate(nil)
        } catch {
            // 脚本没跑起来 兜底打开DMG手动拖
            NSWorkspace.shared.open(fileURL)
            isInstalling = false
        }
    }
}

// MARK: 下载代理 进度回调+临时文件搬运

final class UpdateDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    // 检查阶段从API拿到的安装包标称体积 拿来核对下载物 拦下拿错的包
    let expectedSize: Int64
    let onProgress: (Double, Int64, Int64) -> Void
    let onComplete: (URL) -> Void
    let onError: (String) -> Void

    init(expectedSize: Int64,
         onProgress: @escaping (Double, Int64, Int64) -> Void,
         onComplete: @escaping (URL) -> Void,
         onError: @escaping (String) -> Void) {
        self.expectedSize = expectedSize
        self.onProgress = onProgress
        self.onComplete = onComplete
        self.onError = onError
    }

    // 进度回调 total可能为-1(未知) 调用方用API元数据兜底
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : -1
        let progress = total > 0 ? Double(totalBytesWritten) / Double(total) : 0
        onProgress(min(1, progress), totalBytesWritten, total)
    }

    // 完成回调里当场移走临时文件 回调返回后系统即回收该文件
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // GitHub对不存在的资产回404页 URLSession照样算成功 先验状态码
        if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            onError("服务器返回\(http.statusCode) 安装包可能还没传好")
            return
        }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("owati-update.dmg")
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
        } catch {
            do {
                try FileManager.default.copyItem(at: location, to: dest)
            } catch {
                onError("安装包保存失败")
                return
            }
        }
        // 断流截断的残包挡在安装之前 和服务器报的长度对不上就作废
        if let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path),
           let fileSize = attrs[.size] as? Int64 {
            if let response = downloadTask.response as? HTTPURLResponse,
               response.expectedContentLength > 0,
               fileSize != response.expectedContentLength {
                try? FileManager.default.removeItem(at: dest)
                onError("下载不完整 请重试")
                return
            }
            // 与API标称体积核对 拿错包(如x86_64)在这里拦下
            if expectedSize > 0, fileSize != expectedSize {
                try? FileManager.default.removeItem(at: dest)
                onError("下载到的安装包不对 请重试")
                return
            }
        }
        onComplete(dest)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { onError(error.localizedDescription) }
    }
}

// MARK: 更新窗口 + 对话框

@MainActor
enum UpdateWindow {
    static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            w.title = "软件更新"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: UpdateDialogView())
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

struct UpdateDialogView: View {
    @ObservedObject var checker = UpdateChecker.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.owAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("发现新版本 \(checker.latestVersion ?? "")")
                        .font(.system(size: 17, weight: .bold))
                    Text("重启后即可使用新版本")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
            // 更新内容 Release的Markdown说明 原生渲染
            if let notes = checker.releaseNotes, !notes.isEmpty,
               let attr = try? AttributedString(
                markdown: notes,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                ScrollView(showsIndicators: false) {
                    Text(attr)
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
            // 下载进度
            if checker.isDownloading {
                VStack(spacing: 5) {
                    ProgressView(value: checker.downloadProgress)
                        .tint(.owAccent)
                    HStack {
                        Text("下载中 \(Int(checker.downloadProgress * 100))%")
                            .font(.system(size: 10))
                            .monospacedDigit()
                        Spacer()
                        Text("\(checker.downloadedBytes / 1024) KB")
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
            }
            if checker.isInstalling {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("正在安装… 即将自动重启")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let err = checker.checkError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
            // 按钮区 安装中收起防误点
            if !checker.isInstalling {
            HStack(spacing: 10) {
                Spacer()
                Button {
                    checker.cancelDownload()
                    UpdateWindow.window?.close()
                } label: {
                    Text("稍后再说")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                if checker.downloadDone {
                    Button {
                        checker.installAndRestart()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                            Text("安装并重启")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.owAccent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else if !checker.isDownloading {
                    Button {
                        checker.downloadUpdate()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("下载并安装")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.owAccent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
