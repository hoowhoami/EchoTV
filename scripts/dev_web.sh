#!/bin/bash

# EchoTV Web 开发启动脚本
# 功能：禁用浏览器跨域限制，方便本地调试

echo "🚀 正在以 '禁用 Web 安全策略' 模式启动 EchoTV..."

# 移除了可能引起错误的 --web-renderer 参数
flutter run -d chrome \
  --web-browser-flag "--disable-web-security" \
  --web-browser-flag "--user-data-dir=/tmp/flutter_chrome_dev"