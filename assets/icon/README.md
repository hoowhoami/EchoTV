# EchoTV 图标生成指南

## 📋 文件说明

- `app_icon.svg` - 主图标源文件（满版，无透明边框）
- `app_icon.png` - 主图标 PNG（1024x1024，用于 iOS/Android/Windows/Linux）
- `app_icon_macos.png` - macOS 专用图标 PNG（1024x1024，带透明边框）
- `app_icon_foreground.svg` - Android 自适应图标前景层源文件
- `app_icon_foreground.png` - Android 自适应图标前景层 PNG（1024x1024）

## 🎨 设计说明

### 主图标 (app_icon)
- 1024x1024 画布，内容占满整个画布
- 黑色背景 (#000000)，圆角矩形
- "Echo" 白色文字，换行后 "TV" 蓝色文字 (#4A9EFF)
- 装饰性波纹效果
- 用于：iOS、Android、Windows、Linux

### macOS 专用图标 (app_icon_macos)
- 1024x1024 画布，外围透明边距（约 9%，每边 92px）
- 实际内容区域：840x840（82% 安全区域）
- 设计与主图标相同，但缩小以留出边距
- **重要**：macOS 需要透明边框以正确显示系统圆角和阴影效果

### Android 自适应图标 (app_icon_foreground)
- 1024x1024 画布，完全透明背景
- 只包含文字和装饰元素
- 配合黑色背景层 (#000000)
- 内容居中，适配圆形裁切

## ⚠️ iOS vs macOS 图标差异

**iOS 图标**：
- 内容占满整个画布（无透明边框）
- 系统会自动添加圆角
- 使用 `app_icon.png`

**macOS 图标**：
- 需要外围约 9% 的透明边距（每边约 92px）
- 让系统正确应用圆角、阴影和视觉效果
- 如果不留边距，图标会比其他应用显得更大
- 使用 `app_icon_macos.png`

## 🚀 快速开始

### 1. 转换 SVG 为 PNG

需要生成两个 PNG 文件：
- `app_icon.png` - 满版图标（用于 iOS/Android/Windows/Linux）
- `app_icon_macos.png` - 带透明边框的图标（用于 macOS）
- `app_icon_foreground.png` - Android 自适应图标前景层

**方法 A：使用在线工具（推荐）**
1. 访问 https://cloudconvert.com/svg-to-png
2. 上传 `app_icon.svg` 和 `app_icon_foreground.svg`
3. 设置输出尺寸为 1024x1024
4. 下载并保存为对应的 PNG 文件
5. 对于 macOS 图标：
   - 在图片编辑软件中打开 `app_icon.png`
   - 将内容缩小到 82%（840x840）
   - 居中放置，周围留出透明边框
   - 保存为 `app_icon_macos.png`

**方法 B：使用 ImageMagick（命令行）**
```bash
# 安装 ImageMagick
brew install imagemagick

# 转换主图标（满版）
convert -background none -density 300 app_icon.svg -resize 1024x1024 app_icon.png

# 转换前景图标
convert -background none -density 300 app_icon_foreground.svg -resize 1024x1024 app_icon_foreground.png

# 生成 macOS 图标（带透明边框）
# 方法：将内容缩小到 82%，居中放置
convert app_icon.png -resize 840x840 -gravity center -extent 1024x1024 app_icon_macos.png
```

**方法 C：使用设计工具（Figma/Sketch/Illustrator）**
1. 导入 `app_icon.svg`
2. 导出为 `app_icon.png`（1024x1024）
3. 复制画布，将内容缩小到 82%，居中
4. 导出为 `app_icon_macos.png`（1024x1024）

### 2. 生成所有平台图标

```bash
# 安装依赖（如果还没安装）
flutter pub get

# 生成图标
dart run flutter_launcher_icons

# 重新构建应用
flutter build macos --release  # macOS
flutter build windows --release  # Windows
flutter build linux --release  # Linux
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## 📱 各平台图标说明

### macOS
- 自动生成 AppIcon.appiconset
- 包含多种尺寸：16x16 到 1024x1024
- 系统会自动应用圆角和阴影效果

### Windows
- 生成 app_icon.ico
- 包含多种尺寸：16x16 到 256x256

### Linux
- 生成多个 PNG 文件
- 尺寸：16x16, 32x32, 48x48, 64x64, 128x128, 256x256, 512x512

### Android
- 标准图标：mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}
- 自适应图标：前景层 + 黑色背景层
- 支持圆形、方形、圆角方形等不同形状

### iOS
- 生成 Assets.xcassets/AppIcon.appiconset
- 包含所有需要的尺寸

## 🔧 故障排除

### 问题：图标生成失败
- 确保 PNG 文件存在且尺寸正确（1024x1024）
- 检查 [pubspec.yaml](../../pubspec.yaml) 配置是否正确
- 运行 `flutter clean` 后重试

### 问题：macOS 图标比其他应用大
- 确保使用了 `app_icon_macos.png`（带透明边框的版本）
- 检查 [pubspec.yaml](../../pubspec.yaml) 中 macOS 配置是否指向正确的文件
- 重新生成图标并重新构建应用

### 问题：iOS 图标显示太小
- 确保 iOS 使用的是 `app_icon.png`（满版，无透明边框）
- 不要让 iOS 使用 macOS 的图标文件
- 重新生成图标并重新构建应用

### 问题：Android 图标显示不正常
- 检查前景图标是否有透明背景
- 确保内容在安全区域内（中心 80%）

## 🎨 自定义设计

如果需要修改设计：

1. 编辑 SVG 文件（使用 Figma、Sketch、Illustrator 等）
2. 保持 1024x1024 画布尺寸
3. `app_icon.svg`：内容占满画布（用于 iOS）
4. macOS 版本：将内容缩小到 82%，周围留出透明边框
5. Android 前景：保持透明背景，内容居中
6. 重新转换为 PNG 并生成图标

## 📚 参考资料

- [Flutter Launcher Icons 文档](https://pub.dev/packages/flutter_launcher_icons)
- [Apple Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Android Adaptive Icons](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive)
