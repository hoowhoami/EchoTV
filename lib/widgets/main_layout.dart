import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'zen_ui.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const MainLayout({Key? key, required this.child, required this.currentPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final navItems = [
      {'path': '/', 'label': '首页', 'icon': LucideIcons.home},
      {'path': '/movies', 'label': '电影', 'icon': LucideIcons.film},
      {'path': '/series', 'label': '剧集', 'icon': LucideIcons.clapperboard},
      {'path': '/anime', 'label': '动漫', 'icon': LucideIcons.ghost},
      {'path': '/variety', 'label': '综艺', 'icon': LucideIcons.sparkles},
      {'path': '/live', 'label': '直播', 'icon': LucideIcons.tv},
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(child: child),

          // Top Nav Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => context.go('/search'),
                      icon: Icon(
                        LucideIcons.search,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => context.go('/settings'),
                      icon: Icon(
                        LucideIcons.settings,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Nav
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ZenGlassContainer(
                  borderRadius: 40,
                  blur: 30,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: navItems.map((item) {
                        final isActive = currentPath == item['path'];
                        final isDark = Theme.of(context).brightness == Brightness.dark;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: GestureDetector(
                            onTap: () => context.go(item['path'] as String),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive
                                  ? (isDark ? Colors.white : Colors.black)
                                  : Colors.transparent,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 18,
                                    color: isActive
                                      ? (isDark ? Colors.black : Colors.white)
                                      : Theme.of(context).colorScheme.secondary,
                                  ),
                                  if (isActive) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      item['label'] as String,
                                      style: TextStyle(
                                        color: isDark ? Colors.black : Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
