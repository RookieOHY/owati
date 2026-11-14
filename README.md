# owati

macOS 菜单栏喝水提醒工具。常驻菜单栏不打扰工作，到点温和提醒，随手记一笔，帮你把喝水变成习惯。

## 功能

- **随手记一笔**：点大圆环记一杯；一杯/一瓶一键记录；自定义量支持咖啡、茶、牛奶、果汁，按水合系数折算（水 100%、茶 95%、咖啡牛奶 90%、果汁 85%）
- **温和提醒**：按间隔排队，浮动卡片或全屏页面两种载体；记录一笔即重新计时，刚喝完不会被马上催
- **不打扰机制**：提醒时间段与提醒日、勿扰时段（午休）、会议应用在前台自动暂停、人离开（5 分钟无键鼠）静默滑过，回来补一次
- **节奏自适应**：达标后提醒间隔按倍数放缓，全屏自动降级小卡片；超额静音，连跳催促文案温和升级
- **统计**：近 7 天 / 30 天指标卡、每日水合图、饮品构成
- **成就**：六大系列徽章，实时从记录计算，撤销/改量自动回退
- **使用指南**：底栏帮助（⌘3），含提醒机制六条规则与示例

## 安装

**Homebrew**（推荐，自动更新）：

```bash
brew tap RookieOHY/tap
brew install --cask owati
```

或前往 [Releases](https://github.com/RookieOHY/owati/releases/latest) 下载对应架构的 `.dmg`：

- Apple Silicon（M 系列）：`owati-x.y.z-aarch64.dmg`
- Intel：`owati-x.y.z-x86_64.dmg`

打开后拖入 Applications。首次打开如提示「无法验证开发者」，请前往 **系统设置 → 隐私与安全性 → 仍要打开**。

## 从源码构建

需要 macOS 14+、Swift 5.9+。

```bash
git clone https://github.com/RookieOHY/owati.git
cd owati
./Scripts/package.sh    # release 构建 + 装配 app + 出 DMG，产物在 build/
```

日常调试用 `swift build` 即可。推 `v*` tag 时 GitHub Actions 会自动交叉编译双架构并挂到 Release。

## 数据与隐私

完全离线，不联网、不收集数据。所有记录只存在本机 `~/Library/Application Support/owati/data.db`（SQLite），删除该文件即清空。
