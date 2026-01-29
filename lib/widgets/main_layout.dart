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
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPC = constraints.maxWidth > 800;

        // 核心导航项（移动端底部使用）
        final coreNavItems = [
          {'path': '/', 'label': '首页', 'icon': LucideIcons.home},
          {'path': '/movies', 'label': '电影', 'icon': LucideIcons.film},
          {'path': '/series', 'label': '剧集', 'icon': LucideIcons.clapperboard},
          {'path': '/anime', 'label': '动漫', 'icon': LucideIcons.ghost},
          {'path': '/variety', 'label': '综艺', 'icon': LucideIcons.sparkles},
          {'path': '/live', 'label': '直播', 'icon': LucideIcons.tv},
        ];

        // PC 侧边栏专用导航项（包含搜索）
        final pcNavItems = [
          {'path': '/', 'label': '首页', 'icon': LucideIcons.home},
          {'path': '/search', 'label': '搜索', 'icon': LucideIcons.search},
          {'path': '/movies', 'label': '电影', 'icon': LucideIcons.film},
          {'path': '/series', 'label': '剧集', 'icon': LucideIcons.clapperboard},
          {'path': '/anime', 'label': '动漫', 'icon': LucideIcons.ghost},
          {'path': '/variety', 'label': '综艺', 'icon': LucideIcons.sparkles},
          {'path': '/live', 'label': '直播', 'icon': LucideIcons.tv},
        ];

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Row(
            children: [
              if (isPC)
                Container(
                  width: 240,
                  key: const ValueKey('pc_sidebar'),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(right: BorderSide(color: theme.dividerColor, width: 0.5)),
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'ECHOTV',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontSize: 24,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: pcNavItems.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final item = pcNavItems[index];
                              final isActive = currentPath == item['path'];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SidebarItem(
                                  icon: item['icon'] as IconData,
                                  label: item['label'] as String,
                                  isActive: isActive,
                                  onTap: () => context.go(item['path'] as String),
                                ),
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _SidebarItem(
                            icon: LucideIcons.settings,
                            label: '设置',
                            isActive: currentPath == '/settings',
                            onTap: () => context.go('/settings'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              Expanded(
                key: const ValueKey('main_content_area'), 
                child: child,
              ),
            ],
          ),
          
          // 移动端底部导航保持 6 个核心项
          bottomNavigationBar: isPC ? null : Container(
            key: const ValueKey('mobile_bottom_nav'),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: coreNavItems.map((item) {
                    final isActive = currentPath == item['path'];
                    return GestureDetector(
                      onTap: () => context.go(item['path'] as String),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            size: 22,
                            color: isActive 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.secondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['label'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive 
                                  ? theme.colorScheme.primary 
                                  : theme.colorScheme.secondary.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive 
                  ? (isDark ? Colors.black : Colors.white) 
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive 
                    ? (isDark ? Colors.black : Colors.white) 
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}