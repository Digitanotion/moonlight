// lib/features/live_viewer/presentation/widgets/status/top_status_bar.dart
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/pip_service.dart';
import 'package:moonlight/core/services/share_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

class TopStatusBar extends StatefulWidget {
  const TopStatusBar({super.key});

  @override
  State<TopStatusBar> createState() => _TopStatusBarState();
}

class _TopStatusBarState extends State<TopStatusBar> {
  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

   void _handleAvatarTap(BuildContext context) {
    final host = context.read<ViewerBloc>().state.host;
    if (host == null) return;

    // Popup's own avatar now handles "tap again → profile" directly
    // (see _StreamerInfoPopup._goToProfile) — this just opens it.
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => _StreamerInfoPopup(host: host),
    );
  }

  void _shareStream(BuildContext context) {
    final bloc = context.read<ViewerBloc>();
    final repo = bloc.repo;
    final uuid = repo is ViewerRepositoryImpl ? repo.livestreamParam : null;
    if (uuid == null || uuid.isEmpty) return;

    final host = bloc.state.host;
    ShareService.shareLive(
      livestreamUuid: uuid,
      hostName: host?.name,
      title: host?.title,
    );
    bloc.add(const SharePressed()); // bump the share count server-side
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.elapsed != n.elapsed ||
          p.viewers != n.viewers ||
          p.host != n.host,
      builder: (context, state) {
        final host = state.host;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              if (host != null)
                GestureDetector(
                  onTap: () => _handleAvatarTap(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                    child: ClipOval(
                      child: host.avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: host.avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Colors.white70,
                                size: 18,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 18,
                            ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              _glass(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.circle, color: Colors.redAccent, size: 10),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _glass(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    _fmt(state.elapsed),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => PipService.instance.enterPip(),
                child: _glass(
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.picture_in_picture_alt_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _shareStream(context),
                child: _glass(
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.ios_share_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _glass({required Widget child, double radius = 16, Color? color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 4),
        child: Container(
          decoration: BoxDecoration(
            color: (color ?? Colors.black.withOpacity(.30)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(.08), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StreamerInfoPopup extends StatelessWidget {
  final dynamic host; // HostInfo, kept dynamic to avoid a second import cycle here

  const _StreamerInfoPopup({required this.host});

  void _goToProfile(BuildContext context) {
    if (host.uuid == null || host.uuid!.isEmpty) return;
    Navigator.of(context).pop(); // close the dialog first
    Navigator.of(context).pushNamed(
      RouteNames.profileView,
      arguments: {'userUuid': host.uuid},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141833),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _goToProfile(context),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: ClipOval(
                  child: host.avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: host.avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.person, color: Colors.white54, size: 32),
                        )
                      : const Icon(Icons.person, color: Colors.white54, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              host.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (host.fans != null) ...[
                  const Icon(Icons.favorite, color: Colors.orangeAccent, size: 15),
                  const SizedBox(width: 4),
                  Text('${host.fans} Fans',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 14),
                ],
                if (host.country != null && host.country!.isNotEmpty) ...[
                  const Icon(Icons.public, color: Colors.white54, size: 15),
                  const SizedBox(width: 4),
                  Text('${host.country}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tap the photo again to view profile',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}