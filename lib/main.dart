import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme.dart';
import 'services/config_service.dart';
import 'widgets/edit_dialog.dart';
import 'widgets/zen_ui.dart';
import 'pages/home.dart';
import 'pages/explore.dart';
import 'pages/play.dart';
import 'pages/search.dart';
import 'pages/live.dart';
import 'pages/settings.dart';
import 'providers/settings_provider.dart';
import 'widgets/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 仅在桌面端初始化窗口管理器
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'EchoTV',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      // 拦截原生关闭按钮
      await windowManager.setPreventClose(true);
    });
  }

  runApp(const ProviderScope(child: EchoTVApp()));
}

class EchoTVApp extends ConsumerStatefulWidget {
  const EchoTVApp({super.key});

  @override
  ConsumerState<EchoTVApp> createState() => _EchoTVAppState();
}

class _EchoTVAppState extends ConsumerState<EchoTVApp> with WindowListener {
  bool get _isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_isDesktop) {
      bool isPreventClose = await windowManager.isPreventClose();
      if (isPreventClose) {
        await windowManager.hide();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModelProvider);
    
    // 监听主题变化并更新桌面端窗口亮度
    if (_isDesktop) {
      Brightness brightness;
      if (themeMode == ThemeMode.system) {
        brightness = MediaQuery.platformBrightnessOf(context);
      } else {
        brightness = themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light;
      }
      windowManager.setBrightness(brightness);
    }
    
    return MaterialApp.router(
      title: 'EchoTV',
      debugShowCheckedModeBanner: false,
      theme: ZenTheme.lightTheme(),
      darkTheme: ZenTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: _router,
      builder: (context, child) {
        return TermsGate(child: child!);
      },
    );
  }
}

/// 协议拦截门禁组件
class TermsGate extends ConsumerStatefulWidget {
  final Widget child;
  const TermsGate({super.key, required this.child});

  @override
  ConsumerState<TermsGate> createState() => _TermsGateState();
}

class _TermsGateState extends ConsumerState<TermsGate> {
  bool _hasAgreed = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkTerms();
  }

  Future<void> _checkTerms() async {
    final agreed = await ref.read(configServiceProvider).getHasAgreedTerms();
    if (mounted) {
      setState(() {
        _hasAgreed = agreed;
        _isChecking = false;
      });
    }
  }

  void _onAgree() async {
    await ref.read(configServiceProvider).setHasAgreedTerms(true);
    if (mounted) {
      setState(() => _hasAgreed = true);
    }
  }

  Widget _buildTermsOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: EditDialog(
          title: const Text('用户协议与免责声明'),
          width: 460,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '欢迎使用 EchoTV。在您开始之前，请务必阅读并理解以下条款：',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildTermsItem('1. 工具性质', 'EchoTV 仅作为一个本地/远程资源管理工具，不内置、不提供、不分发任何影视或直播内容。'),
              _buildTermsItem('2. 数据来源', '应用内展示的所有资源均由用户自行配置，用户需对所配置资源的合法性承担全部法律责任。'),
              _buildTermsItem('3. 隐私声明', '我们不会收集您的个人隐私数据，您的配置信息仅存储在您的设备本地或您指定的云端。'),
              const SizedBox(height: 16),
              Text(
                '点击“同意”即代表您已阅读并同意上述条款。若您不同意，请选择“退出应用”。',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
              ),
            ],
          ),
          actions: [
            ZenButton(
              onPressed: () => exit(0),
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              foregroundColor: Theme.of(context).colorScheme.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 44,
              borderRadius: 16,
              child: const Text('退出应用', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),
            ZenButton(
              onPressed: _onAgree,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 44,
              borderRadius: 16,
              child: const Text('同意并继续', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Container(color: Theme.of(context).scaffoldBackgroundColor);
    }
    
    return Stack(
      children: [
        widget.child,
        if (!_hasAgreed) _buildTermsOverlay(context),
      ],
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/play',
      pageBuilder: (context, state) {
        final params = state.uri.queryParameters;
        return _buildPageWithPlatformTransition(
          state,
          PlayPage(
            videoUrl: params['url'] ?? '',
            title: params['title'] ?? '正在播放',
          ),
        );
      },
    ),
    ShellRoute(
      builder: (context, state, child) {
        return MainLayout(
          currentPath: state.matchedLocation,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => _buildPageWithPlatformTransition(
            state,
            const HomePage(),
          ),
        ),
        GoRoute(
          path: '/movies',
          pageBuilder: (context, state) => _buildPageWithPlatformTransition(
            state,
            const ExplorePage(title: '电影', type: 'movie'),
          ),
        ),
        GoRoute(
          path: '/series',
          pageBuilder: (context, state) => _buildPageWithPlatformTransition(
            state,
            const ExplorePage(title: '剧集', type: 'tv'),
          ),
        ),
        GoRoute(
          path: '/anime',
          pageBuilder: (context, state) => _buildPageWithPlatformTransition(
            state,
            const ExplorePage(title: '动漫', type: 'anime'),
          ),
        ),
        GoRoute(
          path: '/variety',
          pageBuilder: (context, state) => _buildPageWithPlatformTransition(
            state,
            const ExplorePage(title: '综艺', type: 'show'),
          ),
        ),
        GoRoute(
          path: '/live',
          pageBuilder: (context, state) => _buildPageWithPlatformTransition(
            state,
            const LivePage(),
          ),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) => _buildPageWithPlatformTransition(
            state,
            const SearchPage(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _buildPageWithPlatformTransition(
            state,
            const SettingsPage(),
          ),
        ),
      ],
    ),
  ],
);

/// 使用系统默认的过渡动画构建页面，这会应用我们在主题中定义的 PageTransitionsTheme

/// 从而在 iOS/macOS 上获得 Cupertino 风格的滑动切换和左滑返回手势

Page _buildPageWithPlatformTransition(GoRouterState state, Widget child) {

  return MaterialPage(

    key: state.pageKey,

    child: child,

  );

}


