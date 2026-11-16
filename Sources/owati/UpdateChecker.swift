import AppKit
import SwiftUI
import Foundation

// MARK: 应用自更新 检查/下载/安装 HealthTick同款流程
// 发布物: GitHub Releases 的 owati-<版本>-<架构>.dmg (package.sh+Actions产出)

let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
let updaterRepo = "RookieOHY/owati"

// uname 识别机器架构 选对应安装包
var machineArch: String {
    var sysinfo = utsname()
    uname(&sysinfo)
    let machine = withUnsafePointer(to: &sysinfo) {
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
        guard let url = URL(string: "https://api.github.com/repos/\(updaterRepo)/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            PanelState.shared.updateStatus = "暂时检查不了 稍后再试"
            checkError = "网络错误"
            return
        }
        guard let tag = obj["tag_name"] as? String else {
            PanelState.shared.updateStatus = "暂时检查不了 稍后再试"
            return
        }
        latestVersion = tag
        releaseNotes = obj["body"] as? String ?? ""

        // 架构匹配的安装包资产
        let dmgName = "owati-\(tag)-\(machineArch).dmg"
        var assetSize: Int64 = 0
        if let assets = obj["assets"] as? [[String: Any]],
           let asset = assets.first(where: { ($0["name"] as? String) == dmgName }),
           let size = asset["size"] as? Int64 ?? (asset["size"] as? Int).map({ Int64($0) }) {
            assetSize = size
        }
        totalBytes = assetSize

        // 与本地版本比对
        if isNewerVersion(tag, than: appVersion) {
            hasUpdate = true
            PanelState.shared.updateStatus = "发现新版本 \(tag) 在更新窗口下载"
            releaseNotes = obj["body"] as? String ?? releaseNotes ?? ""
            UpdateWindow.show()
        } else {
            hasUpdate = false
            PanelState.shared.updateStatus = "已是最新版本 \(tag)"
        }
    }

    // MARK: 下载

    func downloadUpdate() {
        guard hasUpdate, let ver = latestVersion, !isDownloading else { return }
        let dmgName = "owati-\(ver)-\(machineArch).dmg"
        guard let url = URL(string: "https://github.com/\(updaterRepo)/releases/download/v\(ver)/\(dmgName)") else { return }
        isDownloading = true
        downloadDone = false
        downloadProgress = 0

        let delegate = UpdateDownloadDelegate(
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
                    // 移到稳定路径 delegate的临时文件会被清
                    let dest = URL(fileURLWithPath: NSTemporaryDirectory() + "owati-update.dmg")
                    try? FileManager.default.removeItem(at: dest)
                    try? FileManager.default.copyItem(at: fileURL, to: dest)
                    self?.downloadedFileURL = dest
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

    // HealthTick同款 独立bash进程完成替换 运行中的app不能覆盖自己
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
        isInstalling = true

        let script = """
        #!/bin/bash
        DMG_PATH="\(fileURL.path)"
        DEST_APP="\(destApp)"

        MOUNT=$(hdiutil attach "$DMG_PATH" -nobrowse -noverify 2>/dev/null | grep -o '/Volumes/[^\t]*' | head -1)
        if [ -z "$MOUNT" ]; then
            open "$DMG_PATH"
            exit 1
        fi
        SOURCE_APP="$MOUNT/owati.app"
        if [ ! -d "$SOURCE_APP" ]; then
            hdiutil detach "$MOUNT" -quiet 2>/dev/null
            open "$DMG_PATH"
            exit 1
        fi
        sleep 2
        pkill -x owati 2>/dev/null
        rm -rf "$DEST_APP"
        cp -R "$SOURCE_APP" "$DEST_APP"
        hdiutil detach "$MOUNT" -quiet 2>/dev/null
        # 清理下载标记 防Gatekeeper拦截
        xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null
        open "$DEST_APP"
        rm -f "$0"
        """
        let scriptPath = NSTemporaryDirectory() + "owati_update.sh"
        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]
        try? process.run()
        // 脚本会 pkill 旧实例并启动新 app 本体随后自然结束
    }
}

// MARK: 下载代理 进度回调+临时文件搬运

final class UpdateDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double, Int64, Int64) -> Void
    let onComplete: (URL) -> Void
    let onError: (String) -> Void

    init(onProgress: @escaping (Double, Int64, Int64) -> Void,
         onComplete: @escaping (URL) -> Void,
         onError: @escaping (String) -> Void) {
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

    // 完成后把临时文件搬到稳定路径
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        onComplete(location)
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
            // 按钮区
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
        .padding(20)
        .frame(width: 440)
    }
}
