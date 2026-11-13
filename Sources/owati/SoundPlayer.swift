import AVFoundation
import AppKit

// 音效种类 每种一个wav放Resources
enum Sfx: String, CaseIterable {
    case canFizz = "sfx-can-fizz"       // 开罐嘶嘶
    case canPop = "sfx-can-pop"         // 开罐啵
    case pourDeep = "sfx-pour-deep"     // 倒水 咕咚
    case pourBright = "sfx-pour-bright" // 倒水 清亮

    var title: String {
        switch self {
        case .canFizz: return "开罐 · 嘶嘶气泡"
        case .canPop: return "开罐 · 轻啵"
        case .pourDeep: return "倒水 · 咕咚"
        case .pourBright: return "倒水 · 清亮"
        }
    }

    // 横排chips用的短标签
    var short: String {
        switch self {
        case .canFizz: return "开罐嘶嘶"
        case .canPop: return "开罐轻啵"
        case .pourDeep: return "倒水咕咚"
        case .pourBright: return "倒水清亮"
        }
    }
}

// 记录成功的音效 预载全部 重复播
final class SoundPlayer {
    static let shared = SoundPlayer()
    private var players: [Sfx: AVAudioPlayer] = [:]

    private init() {
        for s in Sfx.allCases {
            let path = (#filePath as NSString).deletingLastPathComponent + "/../../Resources/\(s.rawValue).wav"
            if let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) {
                p.volume = 0.4
                p.prepareToPlay()
                players[s] = p
            }
        }
    }

    // 记录成功播当前选中的
    func playLog() {
        guard AppConfig.shared.soundOn else { return }
        playNow(Sfx(rawValue: AppConfig.shared.soundEffect) ?? .canFizz)
    }

    // 提醒出现的一声 比记录声轻 可选苹果官方系统音效 空串=跟随记录音效
    static let systemSoundOptions: [(name: String, label: String)] = [
        ("Bottle", "Bottle · 瓶中咕咚"),
        ("Glass", "Glass · 玻璃杯"),
        ("Ping", "Ping · 叮"),
        ("Tink", "Tink · 轻铃"),
    ]

    func playRemind() {
        guard AppConfig.shared.soundOn else { return }
        let name = AppConfig.shared.remindSound
        if name.isEmpty {
            // 跟随记录音效 音量压轻
            let s = Sfx(rawValue: AppConfig.shared.soundEffect) ?? .canFizz
            guard let p = players[s] else { return }
            p.volume = 0.2
            p.currentTime = 0
            p.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak p] in p?.volume = 0.4 }
        } else if let n = NSSound(named: name) {
            n.stop()
            n.volume = 0.5
            n.play()
        }
    }

    // 设置页试听系统音效
    func previewSystem(_ name: String) {
        if let n = NSSound(named: name) { n.stop(); n.volume = 0.5; n.play() }
    }

    // 设置页试听 不看开关
    func preview(_ s: Sfx) {
        playNow(s)
    }

    private func playNow(_ s: Sfx) {
        guard let p = players[s] else { return }
        p.currentTime = 0
        p.play()
    }
}
