// lib/features/live_viewer/presentation/screens/live_viewer_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:moonlight/features/live_viewer/domain/video_surface_provider.dart';
import '../../domain/entities.dart';
import '../../domain/repositories/viewer_repository.dart';
import '../bloc/viewer_bloc.dart';

class LiveViewerScreen extends StatefulWidget {
  final ViewerRepository repository; // injected
  const LiveViewerScreen({super.key, required this.repository});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Assumes ViewerBloc is provided higher up (e.g., by the route)
    return Scaffold(
      body: _BackgroundVideo(
        repository: widget.repository,
        child: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              // Live ended → toast + pop
              BlocListener<ViewerBloc, ViewerState>(
                listenWhen: (p, n) => p.isEnded != n.isEnded,
                listener: (ctx, s) async {
                  if (s.isEnded) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Live has ended.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    await Future.delayed(const Duration(milliseconds: 600));
                    if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                  }
                },
                child: const SizedBox.shrink(),
              ),

              // overlays
              const _TopStatusBar(),
              const _TopicPill(),
              const _HostCard(),
              const _GuestJoinedBanner(),
              const _GiftToast(),
              const _PauseOverlay(),
              const _WaitingOverlay(),

              // chat (bottom-left)
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 80,
                  ),
                  child: BlocBuilder<ViewerBloc, ViewerState>(
                    buildWhen: (p, n) =>
                        p.showChatUI != n.showChatUI || p.chat != n.chat,
                    builder: (_, s) => Visibility(
                      visible: s.showChatUI,
                      child: const _ChatPanel(),
                    ),
                  ),
                ),
              ),

              // request-to-join (bottom-center)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 90),
                  child: BlocBuilder<ViewerBloc, ViewerState>(
                    buildWhen: (p, n) =>
                        p.showChatUI != n.showChatUI ||
                        p.joinRequested != n.joinRequested ||
                        p.awaitingApproval != n.awaitingApproval ||
                        p.isPaused != n.isPaused,
                    builder: (_, s) => Visibility(
                      visible: !s.isPaused,
                      child: const _RequestToJoinButton(),
                    ),
                  ),
                ),
              ),

              // comment bar (bottom)
              Align(
                alignment: Alignment.bottomCenter,
                child: BlocBuilder<ViewerBloc, ViewerState>(
                  buildWhen: (p, n) => p.showChatUI != n.showChatUI,
                  builder: (_, s) => Visibility(
                    visible: s.showChatUI,
                    child: _CommentBar(
                      controller: _commentCtrl,
                      onSend: (text) {
                        final t = text.trim();
                        if (t.isNotEmpty) {
                          context.read<ViewerBloc>().add(CommentSent(t));
                          _commentCtrl.clear();
                        }
                      },
                    ),
                  ),
                ),
              ),

              // right rail
              const Positioned(right: 10, bottom: 140, child: _RightRail()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Background live video (or fallback image) + optional local preview bubble.
class _BackgroundVideo extends StatelessWidget {
  final Widget child;
  final ViewerRepository repository;
  const _BackgroundVideo({required this.child, required this.repository});

  @override
  Widget build(BuildContext context) {
    final videoProvider = repository is VideoSurfaceProvider
        ? repository as VideoSurfaceProvider
        : null;
    final localPreview = videoProvider?.buildLocalPreview();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (videoProvider != null)
          Positioned.fill(child: videoProvider.buildHostVideo())
        else
          Image.asset(
            'assets/images/onboard_1.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.network(
              'https://images.pexels.com/photos/414886/pexels-photo-414886.jpeg?auto=compress&w=800',
              fit: BoxFit.cover,
            ),
          ),
        // slight darken overlay
        Container(color: Colors.black.withOpacity(0.15)),
        child,
        if (localPreview != null)
          Positioned(
            right: 12,
            bottom: 150, // above the comment bar
            child: localPreview,
          ),
      ],
    );
  }
}

class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar();

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.elapsed != n.elapsed || p.viewers != n.viewers,
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
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
              const Spacer(),
              _glass(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.remove_red_eye_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${state.viewers}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopicPill extends StatelessWidget {
  const _TopicPill();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.host != n.host,
      builder: (_, s) {
        final host = s.host;
        if (host == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 42),
            child: _glass(
              radius: 22,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Text(
                  host.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.host != n.host,
      builder: (_, s) {
        final host = s.host;
        if (host == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 84),
          child: _glass(
            radius: 18,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(host.avatarUrl),
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                host.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  host.badge,
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        context.read<ViewerBloc>().add(const FollowToggled()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: host.isFollowed
                            ? Colors.black.withOpacity(.35)
                            : const Color(0xFFFF7A00),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        host.isFollowed ? 'Following' : 'Follow',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GuestJoinedBanner extends StatelessWidget {
  const _GuestJoinedBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.showGuestBanner != n.showGuestBanner || p.guest != n.guest,
      builder: (_, s) {
        if (!s.showGuestBanner || s.guest == null) {
          return const SizedBox.shrink();
        }
        final n = s.guest!;
        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 150),
            child: _glass(
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flight_takeoff_rounded,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${n.username} ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      n.message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GiftToast extends StatelessWidget {
  const _GiftToast();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.showGiftToast != n.showGiftToast || p.gift != n.gift,
      builder: (_, s) {
        if (!s.showGiftToast || s.gift == null) {
          return const SizedBox.shrink();
        }
        final g = s.gift!;
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 210),
            child: _glass(
              radius: 16,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.card_giftcard,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${g.from} just sent you a ‘${g.giftName}’ gift',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '(worth ${g.coins} coins!)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.redeem,
                        color: Colors.orangeAccent,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.chat != n.chat,
      builder: (_, s) {
        final chat = s.chat.reversed.toList();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220, minWidth: 220),
          child: Stack(
            children: [
              _glass(
                color: Colors.black.withOpacity(.30),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    10,
                    10,
                    34,
                    10,
                  ), // room for ✕
                  child: ListView.separated(
                    reverse: true,
                    shrinkWrap: true,
                    itemCount: chat.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final m = chat[i];
                      return RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${m.username}  ',
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            TextSpan(
                              text: m.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () =>
                      context.read<ViewerBloc>().add(const ChatHideRequested()),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RightRail extends StatelessWidget {
  const _RightRail();

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.likes != n.likes || p.shares != n.shares || p.chat != n.chat,
      builder: (_, s) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // _railButton(
            //   icon: Icons.favorite,
            //   onTap: () => context.read<ViewerBloc>().add(const LikePressed()),
            //   label: _fmtCount(s.likes),
            // ),
            const SizedBox(height: 12),
            _railButton(
              icon: Icons.chat_bubble_outline,
              onTap: () =>
                  context.read<ViewerBloc>().add(const ChatShowRequested()),
              label: "", //_fmtCount(s.chat.length + 1200),
            ),
            // const SizedBox(height: 12),
            // _railButton(
            //   icon: Icons.share_outlined,
            //   onTap: () {
            //     context.read<ViewerBloc>().add(const SharePressed());
            //     ScaffoldMessenger.of(
            //       context,
            //     ).showSnackBar(const SnackBar(content: Text('Share tapped')));
            //   },
            //   label: 'Share',
            // ),
          ],
        );
      },
    );
  }

  Widget _railButton({
    required IconData icon,
    required VoidCallback onTap,
    required String label,
  }) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RequestToJoinButton extends StatelessWidget {
  const _RequestToJoinButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.joinRequested != n.joinRequested ||
          p.awaitingApproval != n.awaitingApproval,
      builder: (_, s) {
        // Treat either flag as "request in flight / made"
        final requestingOrRequested =
            (s.awaitingApproval == true) || (s.joinRequested == true);
        final label = s.awaitingApproval == true
            ? 'Requesting…'
            : (s.joinRequested == true ? 'Requested' : 'Request Guest Box');

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7A00),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onPressed: requestingOrRequested
              ? null
              : () => context.read<ViewerBloc>().add(
                  const RequestToJoinPressed(),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (s.awaitingApproval == true)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.video_call),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }
}

class _CommentBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  const _CommentBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black54],
          stops: [0.0, 1.0],
        ),
      ),
      child: _glass(
        child: Row(
          children: [
            const SizedBox(width: 8),
            const Icon(Icons.emoji_emotions_outlined, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isNotEmpty) onSend(t);
                },
              ),
            ),
            IconButton(
              onPressed: () {
                final t = controller.text.trim();
                if (t.isNotEmpty) onSend(t);
              },
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glass card helper
Widget _glass({required Widget child, double radius = 16, Color? color}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.isPaused != n.isPaused || p.host != n.host,
      builder: (_, s) {
        if (!s.isPaused) return const SizedBox.shrink();
        final host = s.host;
        final handle = host == null
            ? ''
            : '@${host.name.replaceAll(' ', '_').toLowerCase()}';

        return IgnorePointer(
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2B2E83).withOpacity(0.55),
                  const Color(0xFF7B2F9B).withOpacity(0.55),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pause_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Stream Paused',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'The host has temporarily paused this livestream. Please stay tuned...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (host != null)
                  _glass(
                    radius: 22,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(host.avatarUrl),
                            radius: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            handle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Superstar',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withOpacity(.85),
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Leave Stream',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaitingOverlay extends StatelessWidget {
  const _WaitingOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.awaitingApproval != n.awaitingApproval || p.host != n.host,
      builder: (_, s) {
        if (!s.awaitingApproval) return const SizedBox.shrink();
        final host = s.host;
        final handle = host == null
            ? ''
            : '@${host.name.replaceAll(' ', '_').toLowerCase()}';

        return IgnorePointer(
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2B2E83).withOpacity(0.55),
                  const Color(0xFF7B2F9B).withOpacity(0.55),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Waiting for host approval…',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'You’ll join automatically once approved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 18),
                if (host != null)
                  _glass(
                    radius: 22,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(host.avatarUrl),
                            radius: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            handle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
