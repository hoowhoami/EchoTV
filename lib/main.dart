import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:path_provider/path_provider.dart';
import 'core/theme.dart';
import 'pages/home.dart';
import 'pages/explore.dart';
import 'pages/live.dart';
import 'pages/play.dart';
import 'pages/settings.dart';
import 'pages/search.dart';
import 'providers/settings_provider.dart';
import 'services/ad_block_service.dart';
import 'services/config_service.dart';
import 'services/subscription_service.dart';
import 'widgets/main_layout.dart';
import 'widgets/edit_dialog.dart';
import 'widgets/zen_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    // windowManager.ensureInitialized() MUST be called before isFirstInstance()
    // so that the secondary instance's window is hidden immediately on startup,
    // preventing the ghost transparent window in the top-left corner of macOS.
    await windowManager.ensureInitialized();

    // Set onFocus before isFirstInstance() to avoid a race where the gRPC server
    // starts (inside isFirstInstance) but the callback is not yet registered.
    FlutterSingleInstance.onFocus = (_) async {
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      await windowManager.focus();
    };

    if (Platform.isMacOS) {
      // Ensure cache directory exists for FlutterSingleInstance PID file
      final cacheDir = await getApplicationCacheDirectory();
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
    }

    final instance = FlutterSingleInstance();
    if (!(await instance.isFirstInstance())) {
      await instance.focus();
      exit(0);
    }

    WindowOptions windowOptions = const WindowOptions(
      minimumSize: Size(1000, 700),
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final container = ProviderContainer();
  // 初始化广告拦截服务器
  await container.read(adBlockServiceProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EchoTVApp(),
    ),
  );
}

class EchoTVApp extends ConsumerStatefulWidget {
  const EchoTVApp({super.key});

  @override
  ConsumerState<EchoTVApp> createState() => _EchoTVAppState();
}


class _EchoTVAppState extends ConsumerState<EchoTVApp> with WindowListener, TrayListener {
  bool get _isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.setPreventClose(true);
      windowManager.addListener(this);
      trayManager.addListener(this);
      _initTray();
    }
  }

  Future<void> _initTray() async {
    await trayManager.setIcon('assets/icon/app_icon.png');
    await trayManager.setToolTip('EchoTV');
    
    final menu = Menu(
      items: [
        MenuItem(key: 'show_window', label: '显示窗口'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: '退出应用'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }


  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
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
  void onWindowRestore() async {
    await windowManager.show();
    await windowManager.focus();
  }
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      await windowManager.setPreventClose(false);
      await windowManager.close();
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModelProvider);
    
    
    return MaterialApp.router(
      title: 'EchoTV',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
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
      if (agreed) {
        ref.read(subscriptionServiceProvider).checkAndRefreshAutoUpdateSubscriptions();
      }
    }
  }

  void _onAgree() async {
    await ref.read(configServiceProvider).setHasAgreedTerms(true);
    if (mounted) {
      setState(() => _hasAgreed = true);
      ref.read(subscriptionServiceProvider).checkAndRefreshAutoUpdateSubscriptions();
    }
  }

  Widget _buildTermsOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: EditDialog(
          title: const Text('用户条款'),
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
                '点击"同意"即代表您已阅读并同意上述条款。若您不同意，请选择"退出应用"。',
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

Page _buildPageWithPlatformTransition(GoRouterState state, Widget child) {
  return MaterialPage(
    key: state.pageKey,
    child: child,
  );
}
