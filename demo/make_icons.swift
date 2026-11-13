// 生成菜单栏图标 PNG（@1x 22px / @2x 44px）+ 亮暗背景预览图
// 运行：swift demo/make_icons.swift
import AppKit

let fm = FileManager.default
let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
let demoDir = cwd.appendingPathComponent("demo")
let outDir = demoDir.appendingPathComponent("png")
try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)

let svgName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "droplet.svg"
let stem = svgName.replacingOccurrences(of: ".svg", with: "")
let svgURL = demoDir.appendingPathComponent(svgName)
guard let svg = NSImage(contentsOf: svgURL) else {
    fatalError("无法加载 \(svgURL.path)")
}

func rasterize(_ image: NSImage, px: Int) -> NSBitmapImageRep {
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

func pngData(_ rep: NSBitmapImageRep) -> Data {
    rep.representation(using: .png, properties: [:])!
}

let icon22 = rasterize(svg, px: 22)
let icon44 = rasterize(svg, px: 44)
// 大图源 界面里按小尺寸(如28pt)绘制时缩小采样 不会像小图放大那样糊
let icon128 = rasterize(svg, px: 128)
try pngData(icon22).write(to: outDir.appendingPathComponent("\(stem)-22.png"))
try pngData(icon44).write(to: outDir.appendingPathComponent("\(stem)-44.png"))
try pngData(icon128).write(to: outDir.appendingPathComponent("\(stem)-128.png"))

// 黑色 glyph 换色（预览暗色菜单栏用）
func tinted(_ rep: NSBitmapImageRep, _ color: NSColor) -> NSImage {
    let src = NSImage(size: rep.size)
    src.lockFocus()
    rep.draw(in: NSRect(origin: .zero, size: rep.size))
    color.set()
    NSRect(origin: .zero, size: rep.size).fill(using: .sourceAtop)
    src.unlockFocus()
    return src
}

let white22 = tinted(icon22, .white)
let white44 = tinted(icon44, .white)

// 预览图：上亮下暗两行，各显示 1x / 2x 尺寸
let pw = 260, ph = 140
let prev = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
prev.size = NSSize(width: pw, height: ph)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: prev)

NSColor(calibratedWhite: 0.96, alpha: 1).set()
NSRect(x: 0, y: ph/2, width: pw, height: ph/2).fill()
NSColor(calibratedWhite: 0.18, alpha: 1).set()
NSRect(x: 0, y: 0, width: pw, height: ph/2).fill()

let box = { (img: NSImage, x: CGFloat, y: CGFloat, s: CGFloat) in
    img.draw(in: NSRect(x: x, y: y, width: s, height: s))
}
let phC = CGFloat(ph)
// 亮色区（上）：黑 glyph
box(NSImage(data: pngData(icon22))!, 80, phC - 22 - 24, 22)
box(NSImage(data: pngData(icon44))!, 120, phC - 44 - 14, 44)
// 暗色区（下）：白 glyph
box(white22, 80, 24, 22)
box(white44, 120, 14, 44)

NSGraphicsContext.restoreGraphicsState()
try pngData(prev).write(to: outDir.appendingPathComponent("\(stem)-preview.png"))
print("✅ 已生成：demo/png/\(stem)-22.png, \(stem)-44.png, \(stem)-128.png, \(stem)-preview.png")
