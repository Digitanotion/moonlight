// lib/features/live_viewer/presentation/widgets/overlays/role_change_toast.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/widgets/top_snack.dart';

/// Listens to role changes and fires a TopSnack notification.
/// Renders nothing itself — purely a listener widget.
class RoleChangeToast extends StatefulWidget {
  const RoleChangeToast({super.key});

  @override
  State<RoleChangeToast> createState() => _RoleChangeToastState();
}

class _RoleChangeToastState extends State<RoleChangeToast> {
  String? _lastRole;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ViewerBloc, ViewerState>(
      listenWhen: (p, n) => p.currentRole != n.currentRole,
      listener: (ctx, state) {
        final role = state.currentRole;
        if (role == null || role == _lastRole) return;
        _lastRole = role;

        switch (role) {
          case 'guest':
          case 'cohost':
            TopSnack.show(
              ctx,
              "You're now a co-host! Tap ••• to control mic & camera.",
              icon: Icons.star_rounded,
              accent: const Color(0xFFFF7A00),
            );
          case 'audience':
            TopSnack.info(ctx, 'You have been moved back to audience.');
          case 'host':
            TopSnack.success(ctx, 'You are now the host.');
        }
      },
      child: const SizedBox.shrink(),
    );
  }
}
