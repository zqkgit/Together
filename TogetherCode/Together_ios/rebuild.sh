#!/bin/bash
# 一键编译 + 安装 + 启动到模拟器
# 用法：./rebuild.sh
set -e

cd "$(dirname "$0")"

SCHEME="Together_ios"
WORKSPACE="Together_ios.xcworkspace"
BUNDLE_ID="ymjr.com.Together-ios"
# 默认用当前已启动的模拟器；如需指定可改这里，例如 UDID="9086EE2C-0737-4ECE-ADD2-3C561031E7CE"
UDID="${UDID:-$(xcrun simctl list devices booted | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)}"

if [ -z "$UDID" ]; then
  echo "❌ 没有已启动的模拟器，请先在 Xcode/模拟器里打开一个"
  exit 1
fi

echo "🔨 编译中..."
xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" \
  -destination "id=$UDID" -configuration Debug \
  -derivedDataPath build build \
  | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" || true

APP="build/Build/Products/Debug-iphonesimulator/${SCHEME}.app"
if [ ! -d "$APP" ]; then
  echo "❌ 没找到产物 $APP，编译可能失败了"
  exit 1
fi

echo "📱 安装并启动到 $UDID ..."
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID"
echo "✅ 完成"
