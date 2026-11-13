import Foundation

// 资源定位 打包app从Contents/Resources读 swift run开发态回落源码相对路径
// #filePath是编译期源码路径 分发到别人机器上不存在 只能做开发兜底
enum Res {
    static func path(_ name: String) -> String? {
        // 打包app Bundle.main.resourceURL = owati.app/Contents/Resources
        if let dir = Bundle.main.resourceURL {
            let p = dir.appendingPathComponent(name).path
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        // 开发态 swift run 本文件在Sources/owati 下两级是仓库根
        let dev = (#filePath as NSString).deletingLastPathComponent + "/../../" + name
        return FileManager.default.fileExists(atPath: dev) ? dev : nil
    }
}
