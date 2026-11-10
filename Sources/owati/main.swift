import AppKit



// NSApplication 应用全局对象即本APP
let app = NSApplication.shared

// 常驻菜单栏
app.setActivationPolicy(.accessory)

// icon加载和设置宽高
let root = (#filePath as NSString).deletingLastPathComponent + "/../../"
let icon = NSImage(contentsOfFile: root + "demo/png/owati-44.png")!
icon.size = NSSize(width: 22, height: 22)
// 适配亮色+暗色菜单栏+高亮表示选中
icon.isTemplate = true

// 新建菜单项，设置菜单项的图标和提示
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
item.button?.image = icon
item.button?.toolTip = "owati —— 喝水久坐提醒"

// 新建弹出可选项（项目+版本号）（退出应用）
let menu = NSMenu()
menu.addItem(NSMenuItem(title: "owati v0.0.1", action: nil, keyEquivalent: ""))
menu.addItem(.separator())
menu.addItem(NSMenuItem(title: "退出 owati", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

// 将菜单项设置为菜单栏的菜单
item.menu = menu

// 启动应用
app.run()
