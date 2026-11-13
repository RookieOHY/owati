// 生成应用图标 .icns 用的多尺寸 PNG
// 运行: swift Scripts/make_appicon.swift
import AppKit

let fm = FileManager.default
let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
let svgURL = cwd.appendingPathComponent("demo/owati.svg")
let outDir = cwd.appendingPathComponent("build/owati.iconset")
try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)

guard let svg = NSImage(contentsOf: svgURL) else {
    fatalError("无法加载 \(svgURL.path)")
}

func rasterize(_ image: NSImage, px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// iconset 命名规范: 底尺寸 + @2x
let spec: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
for (name, px) in spec {
    try rasterize(svg, px: px).write(to: outDir.appendingPathComponent(name))
}
print("iconset 已生成 \(outDir.path)")
