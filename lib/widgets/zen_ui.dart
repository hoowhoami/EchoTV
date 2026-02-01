import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/movie.dart';
import 'cover_image.dart';

class ZenScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  const ZenScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: backgroundColor ?? theme.scaffoldBackgroundColor,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }
}

class ZenSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeTrackColor;
  final Color? inactiveTrackColor;
  final double scale;

  const ZenSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.scale = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Transform.scale(
      scale: scale,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: theme.colorScheme.onPrimary,
        activeTrackColor: activeTrackColor ?? theme.colorScheme.primary,
        inactiveThumbColor: isDark ? Colors.white38 : Colors.white,
        inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.1);
        }),
      ),
    );
  }
}

class ZenButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final EdgeInsets padding;
  final double? height;
  final bool isSecondary;

  const ZenButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 14, // 稍微减小圆角，显得更现代
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.height,
    this.isSecondary = false,
  });

  @override
  State<ZenButton> createState() => _ZenButtonState();
}

class _ZenButtonState extends State<ZenButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color bgColor;
    Color fgColor;

    if (widget.isSecondary) {
      bgColor = widget.backgroundColor ?? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05));
      fgColor = widget.foregroundColor ?? theme.colorScheme.onSurface;
      if (_isHovered) bgColor = bgColor.withValues(alpha: bgColor.opacity + 0.05);
    } else {
      bgColor = widget.backgroundColor ?? theme.colorScheme.primary;
      fgColor = widget.foregroundColor ?? (isDark ? Colors.black : Colors.white);
      if (_isHovered) bgColor = bgColor.withValues(alpha: 0.9);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: widget.height,
            padding: widget.padding,
            alignment: widget.height != null ? Alignment.center : null,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: !widget.isSecondary && _isHovered ? [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ] : null,
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                color: fgColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class ZenGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? backgroundColor;
  final double opacity;

  const ZenGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 40,
    this.blur = 40,
    this.backgroundColor,
    this.opacity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: (backgroundColor ?? Theme.of(context).colorScheme.surface).withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ZenSliverAppBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget>? actions;
  final double? expandedHeight;

  const ZenSliverAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions,
    this.expandedHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPC = MediaQuery.of(context).size.width > 800;
    final horizontalPadding = isPC ? 48.0 : 24.0;
    final canPop = Navigator.canPop(context);
    final topPadding = MediaQuery.of(context).padding.top;
    
    // 采用更紧凑的固定高度，匹配“收缩后”的视觉感
    final headerHeight = expandedHeight ?? (isPC ? 72.0 : 64.0);

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      expandedHeight: headerHeight,
      toolbarHeight: headerHeight, // 确保工具栏高度也同步，防止布局偏移
      floating: true,
      pinned: false,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        padding: EdgeInsets.only(top: topPadding),
        child: Row(
          children: [
            if (canPop)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: IconButton(
                  icon: Icon(
                    LucideIcons.chevronLeft,
                    size: 24,
                    color: theme.colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: canPop ? 12 : horizontalPadding,
                  right: horizontalPadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: isPC ? 22 : 18,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            if (actions != null)
              Padding(
                padding: EdgeInsets.only(right: horizontalPadding - 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ),
          ],
        ),
      ),
    );
  }
}

class MovieCard extends ConsumerWidget {
  final DoubanSubject movie;
  final VoidCallback onTap;
  final String? badge;

  const MovieCard({super.key, required this.movie, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CoverImage(imageUrl: movie.cover),
              ),
              if (badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            '⭐ ${movie.rate}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontSize: 11,
              fontWeight: FontWeight.bold
            ),
          ),
        ],
      ),
    ));
  }
}
