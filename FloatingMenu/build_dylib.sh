#!/usr/bin/env bash
# 本地 Mac 编译：把悬浮窗模块编译成 FloatingMenu.dylib
# 依赖：Xcode 命令行工具（提供 xcrun + iOS SDK）
set -e
cd "$(dirname "$0")"

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
echo "using SDK: $SDK"

xcrun clang \
  -target arm64-apple-ios14.0 \
  -dynamiclib \
  -fobjc-arc \
  -isysroot "$SDK" \
  -I. \
  entry.m FloatingMenu.m FeatureManager.m Features.m MemoryPatcher.m \
  -framework Foundation \
  -framework UIKit \
  -install_name @executable_path/Frameworks/FloatingMenu.dylib \
  -o FloatingMenu.dylib

echo "built -> FloatingMenu.dylib"
