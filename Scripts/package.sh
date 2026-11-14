#!/bin/bash
# 打包 owati.app: release构建 + icns + Info.plist 装配 ad-hoc签名
set -e
cd "$(dirname "$0")/.."
APP=build/owati.app
# 版本号: Actions打tag时取tag名(v0.1.1 -> 0.1.1) 本地默认0.1.0
VERSION="${GITHUB_REF_NAME#v}"
[ -z "$VERSION" ] && VERSION="0.1.0"
# 云端双架构时 Actions注入ARCH 产物名带后缀区分
[ -n "$ARCH" ] && SUFFIX="-$ARCH"

# 1. release构建 CI注入ARCH时交叉编译(--arch) 单台arm64机器双架构全包
if [ -n "$ARCH" ]; then
    swift build -c release --arch "$ARCH"
else
    swift build -c release
fi

# 2. 应用图标 多尺寸PNG -> icns
swift Scripts/make_appicon.swift
rm -rf build/owati.icns
iconutil -c icns build/owati.iconset -o build/owati.icns

# 3. 装配 .app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/owati "$APP/Contents/MacOS/owati"
cp build/owati.icns "$APP/Contents/Resources/owati.icns"
# 运行时资源 Res定位器从bundle读: 菜单栏/面板图标 + 音效wav
cp demo/png/owati-44.png demo/png/owati-128.png "$APP/Contents/Resources/"
cp Resources/*.wav "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>owati</string>
    <key>CFBundleDisplayName</key><string>owati</string>
    <key>CFBundleIdentifier</key><string>com.rookieohy.owati</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>owati</string>
    <key>CFBundleExecutable</key><string>owati</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
EOF

# 4. ad-hoc签名 本地双击可跑
codesign --force --sign - "$APP" 2>/dev/null || true

# 5. DMG分发镜像 拖拽安装形态 打完即清暂存 防止Spotlight索引出重复应用
rm -rf build/dmg-staging
mkdir -p build/dmg-staging
cp -R "$APP" build/dmg-staging/
ln -s /Applications build/dmg-staging/Applications
rm -f "build/owati-$VERSION$SUFFIX.dmg"
hdiutil create -volname owati -srcfolder build/dmg-staging -ov -format UDZO "build/owati-$VERSION$SUFFIX.dmg" -quiet
rm -rf build/dmg-staging

echo "✅ 打包完成: $APP (版本 $VERSION)"
echo "   分发包: build/owati-$VERSION$SUFFIX.dmg"
