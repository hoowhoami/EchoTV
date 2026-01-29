# 📺 EchoTV

<p align="center">
  <img src="web/favicon.png" width="128" height="128" alt="EchoTV Logo">
  <br>
  <b>极致纯净的 Zen-iOS 风格全平台视频客户端</b>
  <br>
  <i>「 视界随心，静谧无界 」</i>
</p>

---

## 🎐 设计理念：Zen-iOS Hybrid

EchoTV 不仅仅是一个播放器，它是一场视觉修行。我们摒弃了传统播放器的繁琐与杂乱，追求：

- **物理触感 (Tactile Physics)**：每一次点击都带有 `active:scale-95` 的真实物理回弹。
- **光学模糊 (Optic Blur)**：深度应用 `BackdropFilter`，营造出多层有机玻璃堆叠的通透感。
- **工业美学 (Industrial Aesthetic)**：采用 Inter 字体配合冷灰调 (#F2F2F7) 高对比度排版，严谨且优雅。
- **极致平滑 (Pure Fluidity)**：全应用跨平台支持 Cupertino 风格的物理滑动与原地淡入淡出。

---

## 🌟 核心特性

- 📽️ **影视发现**：深度整合豆瓣热门数据，将精选内容与自定义资源站智能匹配。
- 📺 **全能直播**：支持标准 M3U 格式订阅，内置高效的直播源解析与分类。
- 🔗 **多源聚合**：支持 AppleCMS (JSON) 接口，轻松管理你的私有资源库。
- 🛡️ **青少年模式**：内置内容过滤引擎，通过自定义关键字与模式切换，为家人提供纯净环境。
- 🔄 **配置同步**：支持通过远程 URL 或本地 JSON 导出/导入完整配置，多端同步无阻碍。
- 🛠️ **多维代理**：针对不同网络环境，提供多种豆瓣 API 及图片镜像代理选择。

---

## 📱 平台支持

EchoTV 基于 Flutter 构建，实现了真正的全平台一致性体验：

| 平台 | 状态 | 产物格式 | 说明 |
| :--- | :--- | :--- | :--- |
| **macOS** | ✅ 完美支持 | `.dmg` / `.app` | 深度适配 Apple Silicon 与 Intel |
| **iOS** | ✅ 完美支持 | `.ipa` | 支持 AltStore/Sideloadly 手动签名 |
| **Android** | ✅ 完美支持 | `.apk` | 适配不同架构的安装包 |
| **Windows** | ✅ 完美支持 | `.zip` | 绿色版运行，无需安装 |
| **Linux** | ✅ 完美支持 | `.tar.gz` | 基于 GTK+ 构建 |
| **Web** | ✅ 预览支持 | `HTML/JS` | 基础功能预览 |

---

## 🛠️ 技术选型

- **核心框架**: Flutter 3.x
- **状态管理**: [Riverpod](https://riverpod.dev/) (响应式、类型安全)
- **路由系统**: [GoRouter](https://pub.dev/packages/go_router) (声明式路由)
- **图标系统**: [Lucide Icons](https://lucide.dev/) (极致精简)
- **字体规范**: [Google Fonts (Inter)](https://fonts.google.com/specimen/Inter)
- **持久化**: Shared Preferences + Custom Config Service

---

## 🚀 开发者指南

### 环境准备
- Flutter SDK (latest stable)
- 各平台对应的开发环境 (Xcode, Android Studio, Visual Studio, etc.)

### 快速启动
```bash
# 克隆仓库
git clone https://github.com/your-username/EchoTV.git

# 安装依赖
flutter pub get

# 运行应用 (自动识别当前连接的设备)
flutter run
```

### 自动化发布
项目内置了完善的 GitHub Actions 工作流，只需推送版本标签即可触发全平台构建：
```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## 📜 开源协议

本项目遵循 [MIT License](LICENSE) 协议。

---

<p align="center">
  由 <b>EchoTV Team</b> 倾力打造
</p>
