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
      builder: (context, state) {
        final params = state.uri.queryParameters;
        return PlayPage(
          videoUrl: params['url'] ?? '',
          title: params['title'] ?? '正在播放',
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
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/movies',
          builder: (context, state) => const ExplorePage(title: '电影', type: 'movie'),
        ),
        GoRoute(
          path: '/series',
          builder: (context, state) => const ExplorePage(title: '剧集', type: 'tv'),
        ),
        GoRoute(
          path: '/anime',
          builder: (context, state) => const ExplorePage(title: '动漫', type: 'anime'),
        ),
        GoRoute(
          path: '/live',
          builder: (context, state) => const LivePage(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);

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