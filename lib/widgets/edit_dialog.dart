import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A shared edit dialog component used for both adding and editing items.
class EditDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final double? width;

  const EditDialog({Key? key, required this.title, required this.content, required this.actions, this.width}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final minHorizontalMargin = screenWidth <= 360
        ? 12.0
        : screenWidth <= 480
            ? 16.0
            : 32.0;
    final maxDialogWidth = math.max(0.0, screenWidth - (minHorizontalMargin * 2));
    final dialogWidth = width ?? math.min(600, maxDialogWidth);
    final insetHorizontal = math.max(minHorizontalMargin, (screenWidth - dialogWidth) / 2);
    final insetPadding = isDesktop
        ? const EdgeInsets.symmetric(horizontal: 40, vertical: 24)
        : EdgeInsets.symmetric(horizontal: insetHorizontal, vertical: 24);
    return Center(
      child: SizedBox(
        width: dialogWidth,
        child: AlertDialog(
          insetPadding: insetPadding,
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: title,
          content: ConstrainedBox(
            constraints: BoxConstraints(minWidth: dialogWidth),
            child: content,
          ),
          actions: actions,
        ),
      ),
    );
  }
}
