import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'pages/home.dart';
import 'pages/explore.dart';
import 'pages/play.dart';
import 'pages/search.dart';
import 'pages/live.dart';
import 'pages/settings.dart';
import 'providers/settings_provider.dart';
import 'widgets/main_layout.dart';

void main() {
  runApp(const ProviderScope(child: EchoTVApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/play',
      pageBuilder: (context, state) {
        final params = state.uri.queryParameters;
        return CustomTransitionPage(
          key: state.pageKey,
          child: PlayPage(
            videoUrl: params['url'] ?? '',
            title: params['title'] ?? '正在播放',
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
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
          pageBuilder: (context, state) => _buildPageWithFadeTransition(
            state,
            const HomePage(),
          ),
        ),
        GoRoute(
          path: '/movies',
          pageBuilder: (context, state) => _buildPageWithFadeTransition(
            state,
            const ExplorePage(title: '电影', type: 'movie'),
          ),
        ),
        GoRoute(
          path: '/series',
          pageBuilder: (context, state) => _buildPageWithFadeTransition(
            state,
            const ExplorePage(title: '剧集', type: 'tv'),
          ),
        ),
        GoRoute(
          path: '/anime',
          pageBuilder: (context, state) => _buildPageWithFadeTransition(
            state,
            const ExplorePage(title: '动漫', type: 'anime'),
          ),
        ),
        GoRoute(
          path: '/variety',
          pageBuilder: (context, state) => _buildPageWithFadeTransition(
            state,
            const ExplorePage(title: '综艺', type: 'show'),
          ),
        ),
        GoRoute(
          path: '/live',
          pageBuilder: (context, state) => _buildPageWithFadeTransition(
            state,
            const LivePage(),
          ),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) => _buildPageWithFadeTransition(
            state,
            const SearchPage(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _buildPageWithFadeTransition(
            state,
            const SettingsPage(),
          ),
        ),
      ],
    ),
  ],
);

/// 构建带淡入淡出过渡动画的页面
CustomTransitionPage _buildPageWithFadeTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // 使用滑动 + 淡入动画，让新页面立即覆盖旧页面
      const begin = Offset(0.05, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOut;

      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final offsetAnimation = animation.drive(tween);

      final fadeAnimation = CurveTween(curve: Curves.easeIn).animate(animation);

      return SlideTransition(
        position: offsetAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: child,
        ),
      );
    },
  );
}

class EchoTVApp extends ConsumerWidget {
  const EchoTVApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModelProvider);
    
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