import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme.dart';
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


