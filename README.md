# EchoTV

EchoTV 是一款遵循 **"Zen-iOS Hybrid"** 设计语言的极致流媒体客户端。它融合了豆瓣的发现能力与多源 CMS 的播放能力，为用户提供纯净、流畅的影视体验。

## 核心特性

- 🎨 **Zen-iOS 视觉**：高强度光学模糊 (Backdrop Blur)、物理回弹触感、冷灰调高对比度排版。
- 🔍 **智能聚合**：自动将豆瓣热门榜单与配置的 CMS 资源站进行匹配，实现“一键即播”。
- 📺 **电视直播**：支持 M3U 格式订阅，内置高质量直播源解析。
- 🌐 **多源管理**：灵活添加自定义 CMS (AppleCMS/JSON API) 源，打造个人影视库。
- 🚀 **极致性能**：基于 Flutter 构建，支持全平台（iOS/Android/macOS/Web）流畅运行。

## 技术架构

- **UI**: Flutter Custom Theme + Lucide Icons + Inter Font
- **State**: Riverpod (Reactive State Management)
- **Networking**: Dio + Douban Mirror API
- **Player**: Chewie + video_player
- **Routing**: GoRouter (ShellRoute Layout)

## 快速开始

```bash
flutter pub get
flutter run
```

## 设计规范

- **底色**: `#F2F2F7` (Light) / `#000000` (Dark)
- **圆角**: 容器 `40px`, 功能块 `28px`, 小组件 `20px`
- **模糊**: `sigma: 40` (Glassmorphism)
- **反馈**: `active:scale-95` (Tactile Physics)