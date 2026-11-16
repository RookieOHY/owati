import Foundation

// 资源定位 打包app从Contents/Resources读 swift run开发态回落源码相对路径
// #filePath是编译期源码路径 分发到别人机器上不存在 只能做开发兜底
enum Res {
    static func path(_ name: String) -> String? {
        // 打包资源是平铺进Resources的 去掉源码目录层级按文件名找
        if let dir = Bundle.main.resourceURL {
            let flat = (name as NSString).lastPathComponent
            let p = dir.appendingPathComponent(flat).path
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        // 开发态 swift run 本文件在Sources/owati 下两级是仓库根
        let dev = (#filePath as NSString).deletingLastPathComponent + "/../../" + name
        return FileManager.default.fileExists(atPath: dev) ? dev : nil
    }
}
