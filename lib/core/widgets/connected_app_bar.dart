// lib/core/widgets/connected_app_bar.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/widgets/connection_status_widget.dart';

class ConnectedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final double elevation;
  final ShapeBorder? shape;
  final bool centerTitle;
  final double toolbarHeight;
  final double? titleSpacing;
  final TextStyle? titleTextStyle;

  const ConnectedAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.elevation = 4,
    this.shape,
    this.centerTitle = true,
    this.toolbarHeight = kToolbarHeight,
    this.titleSpacing,
    this.titleTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Connection status bar (shows only when disconnected)
        ConnectionStatusWidget(
          showOnlyWhenDisconnected: true,
          hideAfter: const Duration(seconds: 5),
        ),

        // The actual AppBar
        AppBar(
          key: key,
          title: title,
          actions: actions,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          backgroundColor: backgroundColor,
          elevation: elevation,
          shape: shape,
          centerTitle: centerTitle,
          toolbarHeight: toolbarHeight,
          titleSpacing: titleSpacing,
          titleTextStyle: titleTextStyle,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    toolbarHeight + kToolbarHeight, // AppBar + potential status bar
  );
}
