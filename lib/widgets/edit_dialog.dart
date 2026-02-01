import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A shared edit dialog component used for both adding and editing items.
class EditDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final double? width;

  const EditDialog({super.key, required this.title, required this.content, required this.actions, this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    
    final minHorizontalMargin = screenWidth <= 360
        ? 12.0
        : screenWidth <= 480
            ? 16.0
            : 32.0;
    final maxDialogWidth = math.max(0.0, screenWidth - (minHorizontalMargin * 2));
    final dialogWidth = width ?? math.min(500, maxDialogWidth);
    
    return Center(
      child: Container(
        width: dialogWidth,
        margin: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: theme.brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 48,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题栏 - 显式设置样式确保可见性
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                child: DefaultTextStyle(
                  style: theme.textTheme.titleLarge!.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  child: title,
                ),
              ),
              // 内容区
              Padding(
                padding: const EdgeInsets.all(28),
                child: content,
              ),
              // 操作按钮区
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions.map((action) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: action,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
