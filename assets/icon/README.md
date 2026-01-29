# EchoTV 图标生成指南

## 📋 文件说明

- `app_icon.svg` - 主图标源文件（包含 macOS 透明边距）
- `app_icon.png` - 主图标 PNG（1024x1024）
- `app_icon_foreground.svg` - Android 自适应图标前景层源文件
- `app_icon_foreground.png` - Android 自适应图标前景层 PNG（1024x1024）

## 🎨 设计说明

### 主图标 (app_icon)
- 1024x1024 画布，外围透明边距（macOS 要求）
- 实际内容区域：840x840（82% 安全区域）
- 黑色背景 (#000000)，圆角矩形
- "Echo" 白色文字，换行后 "TV" 蓝色文字 (#4A9EFF)
- 装饰性波纹效果

### Android 自适应图标 (app_icon_foreground)
- 1024x1024 画布，完全透明背景
- 只包含文字和装饰元素
- 配合黑色背景层 (#000000)
- 内容居中，适配圆形裁切

## ⚠️ macOS 图标特殊要求

**重要**：macOS 图标必须在外围留出约 9% 的透明边距（每边约 92px）

- **原因**：让系统正确应用圆角、阴影和视觉效果
- **如果不留边距**：图标会比其他应用显得更大
- **已处理**：SVG 中内容已缩小到 840x840，居中放置

## 🚀 快速开始

### 1. 转换 SVG 为 PNG

如果你已经有 PNG 文件，跳过此步骤。

**方法 A：使用在线工具（推荐）**
1. 访问 https://cloudconvert.com/svg-to-png
2. 上传 `app_icon.svg` 和 `app_icon_foreground.svg`
3. 设置输出尺寸为 1024x1024
4. 下载并保存为对应的 PNG 文件

**方法 B：使用 ImageMagick（命令行）**
```bash
# 安装 ImageMagick
brew install imagemagick

# 转换主图标
convert -background none -density 300 app_icon.svg -resize 1024x1024 app_icon.png

# 转换前景图标
convert -background none -density 300 app_icon_foreground.svg -resize 1024x1024 app_icon_foreground.png
```

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
- 检查 pubspec.yaml 配置是否正确
- 运行 `flutter clean` 后重试

### 问题：macOS 图标比其他应用大
- 确保使用了带透明边距的版本
- 重新生成图标并重新构建应用

### 问题：Android 图标显示不正常
- 检查前景图标是否有透明背景
- 确保内容在安全区域内（中心 80%）

## 🎨 自定义设计

如果需要修改设计：

1. 编辑 SVG 文件（使用 Figma、Sketch、Illustrator 等）
2. 保持 1024x1024 画布尺寸
3. macOS 版本：保留外围 92px 透明边距
4. Android 前景：保持透明背景，内容居中
5. 重新转换为 PNG 并生成图标

## 📚 参考资料

- [Flutter Launcher Icons 文档](https://pub.dev/packages/flutter_launcher_icons)
- [Apple Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Android Adaptive Icons](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive)

### 方法 2：使用 ImageMagick（命令行）
```bash
# 安装 ImageMagick（如果未安装）
brew install imagemagick

# 转换 SVG 为 PNG
convert -background none -density 300 app_icon.svg -resize 1024x1024 app_icon.png
```

### 方法 3：使用 Figma/Sketch/Adobe Illustrator
1. 在设计工具中创建 1024x1024 画布
2. 黑色背景，圆角 180px
3. 添加文字：
   - "Echo"：白色，字号约 180px，居中
   - "TV"：蓝色 (#4A9EFF)，字号约 200px，居中，位于 Echo 下方
4. 导出为 PNG，1024x1024

### 方法 4：使用 Canva（最简单）
1. 访问 https://www.canva.com
2. 创建 1024x1024 自定义尺寸
3. 设置黑色背景
4. 添加文字 "Echo" 和 "TV"，按设计排列
5. 下载为 PNG

## 生成自适应图标（Android）
对于 Android 自适应图标，需要创建前景图层：
- 创建 `app_icon_foreground.png`（1024x1024）
- 只包含 "Echo" 和 "TV" 文字，背景透明
- 文字居中，留出安全边距（约 20%）

## 生成所有平台图标

完成 PNG 文件后，运行：

```bash
# 安装依赖
flutter pub get

# 生成图标
dart run flutter_launcher_icons
```

这将自动为所有平台生成正确尺寸的图标：
- Android: mipmap 各种分辨率
- iOS: Assets.xcassets
- macOS: AppIcon.appiconset
- Windows: app_icon.ico
- Linux: 各种尺寸的 PNG

## 注意事项

### macOS 特殊要求
- macOS 图标需要圆角，flutter_launcher_icons 会自动处理
- 建议使用 1024x1024 高分辨率源文件
- macOS 会自动应用系统圆角样式

### 图标设计建议
- 保持简洁，避免过多细节
- 文字要清晰可读，即使在小尺寸下
- 黑色背景在深色模式下效果更好
- 考虑添加微妙的渐变或光效提升质感
