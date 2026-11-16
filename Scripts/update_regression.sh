#!/bin/bash
# 更新器回归测试: 装回指定的旧版并启动 由人走完 应用内检查更新→下载→安装→自动重启
# 用法: Scripts/update_regression.sh <旧tag>   例: Scripts/update_regression.sh v0.1.5
# 前提: 该tag的发布里有 *aarch64*.dmg 且那一版已带更新器(v0.1.5起)
set -e
cd "$(dirname "$0")/.."
TAG="${1:?用法: Scripts/update_regression.sh <旧tag 如 v0.1.5>}"

pkill -x owati 2>/dev/null || true
sleep 1

echo "下载 $TAG 的 aarch64 包..."
gh release download "$TAG" -R RookieOHY/owati -p '*aarch64*.dmg' -O /tmp/owati_regression.dmg --clobber

MOUNT=$(hdiutil attach /tmp/owati_regression.dmg -nobrowse -noverify 2>/dev/null | grep -o '/Volumes/[^\t]*' | head -1)
if [ -z "$MOUNT" ]; then
    echo "❌ 挂载失败"
    exit 1
fi

rm -rf build/owati.app
cp -R "$MOUNT/owati.app" build/owati.app
hdiutil detach "$MOUNT" -quiet 2>/dev/null

open build/owati.app
sleep 2
pgrep -x owati >/dev/null && echo "✅ 旧版 $TAG 已装好并启动" || { echo "❌ 启动失败"; exit 1; }
echo "现在人工走: 菜单栏→关于→检查更新→下载并安装→安装并重启"
echo "通过标准: 自动重启后 关于页版本号 > $TAG"
