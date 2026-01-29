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

        final coreNavItems = [
          {'path': '/', 'label': '首页', 'icon': LucideIcons.home},
          {'path': '/movies', 'label': '电影', 'icon': LucideIcons.film},
          {'path': '/series', 'label': '剧集', 'icon': LucideIcons.clapperboard},
          {'path': '/anime', 'label': '动漫', 'icon': LucideIcons.ghost},
          {'path': '/variety', 'label': '综艺', 'icon': LucideIcons.sparkles},
          {'path': '/live', 'label': '直播', 'icon': LucideIcons.tv},
        ];

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
                  width: 220, // 稍微缩窄，显得更利落
                  key: const ValueKey('pc_sidebar'),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(right: BorderSide(color: theme.dividerColor, width: 0.5)),
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo 区域 - 更加精致小巧
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 40, 24, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ECHOTV',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 12,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        Expanded(
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false), // 隐藏滚动条
                            child: ListView.builder(
                              itemCount: pcNavItems.length,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              physics: const BouncingScrollPhysics(), // 恢复滚动并增加弹性
                              itemBuilder: (context, index) {
                                final item = pcNavItems[index];
                                final isActive = currentPath == item['path'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
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
                        ),
                        
                        // 底部设置区域
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _SidebarItem(
                            icon: LucideIcons.settings,
                            label: '系统设置',
                            isActive: currentPath == '/settings',
                            onTap: () => context.go('/settings'),
                          ),
                        ),
                        const SizedBox(height: 8),
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

class _SidebarItem extends StatefulWidget {
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
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive 
                ? theme.colorScheme.primary 
                : (_isHovered ? theme.colorScheme.onSurface.withValues(alpha: 0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isActive 
                    ? (isDark ? Colors.black : Colors.white) 
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 14),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: widget.isActive ? FontWeight.w900 : FontWeight.w500,
                  color: widget.isActive 
                      ? (isDark ? Colors.black : Colors.white) 
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
