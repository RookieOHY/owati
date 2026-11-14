// 生成应用图标 .icns 用的多尺寸 PNG
// macOS标准形态: 品牌蓝渐变圆角方板 + 白水滴居中(和关于页徽标同款)
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

// 水滴 glyph 反白 (黑模板 -> 白)
func whiteDroplet(px: Int) -> NSImage {
    let rep = rasterizedRep(svg, px: px)
    let out = NSImage(size: NSSize(width: px, height: px))
    out.lockFocus()
    rep.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSColor.white.set()
    NSRect(x: 0, y: 0, width: px, height: px).fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

func rasterizedRep(_ image: NSImage, px: Int) -> NSBitmapImageRep {
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
    return rep
}

// 单枚图标: 方板占画布80% 苹果观感留边 水滴占方板56%
func appIcon(px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(px)
    let plate = s * 0.8
    let plateRect = NSRect(x: (s - plate) / 2, y: (s - plate) / 2, width: plate, height: plate)
    // 方板 产品蓝渐变 圆角比例约squircle
    let platePath = NSBezierPath(roundedRect: plateRect, xRadius: plate * 0.225, yRadius: plate * 0.225)
    let grad = NSGradient(colors: [
        NSColor(red: 0.08, green: 0.5, blue: 1.0, alpha: 1),
        NSColor(red: 0.04, green: 0.36, blue: 0.85, alpha: 1),
    ])!
    grad.draw(in: platePath, angle: -90)

    // 白水滴 居中
    let dropSide = plate * 0.56
    let drop = whiteDroplet(px: Int(dropSide) * 2)   // 2x超采样 缩放更锐
    drop.draw(in: NSRect(x: (s - dropSide) / 2, y: (s - dropSide) / 2, width: dropSide, height: dropSide))

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
    try appIcon(px: px).write(to: outDir.appendingPathComponent(name))
}
print("iconset 已生成 \(outDir.path)")
