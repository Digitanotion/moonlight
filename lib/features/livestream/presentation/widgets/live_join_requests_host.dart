// lib/features/livestream/presentation/widgets/live_join_requests_host.dart
//
// Host side of "join the box": a pop-up for every viewer who taps Join
// (Approve / Decline), one after another, and actions for guests already in
// the box (send back to watching, or remove from the live).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/live_guest_strip.dart';
import 'package:moonlight/widgets/top_snack.dart';

class _JoinReq {
  final String id;
  final String name;
  final String avatar;
  const _JoinReq(this.id, this.name, this.avatar);

  factory _JoinReq.fromJson(Map m) {
    final u = Map<String, dynamic>.from((m['user'] as Map?) ?? const {});
    return _JoinReq(
      (m['id'] ?? m['request_id'] ?? '').toString(),
      (u['display_name'] ?? u['user_slug'] ?? 'Someone').toString(),
      (u['avatar'] ?? u['avatar_url'] ?? '').toString(),
    );
  }
}

/// Host side of join requests: a small flag under the top bar for the
/// newest request (✓ / ✕ right there), a "+N" counter, and a live list of
/// every waiting request — so several requests never cover the video.
/// Must sit directly inside the host screen's Stack.
class LiveJoinRequestsHost extends StatefulWidget {
  final int livestreamId;
  final double top;
  const LiveJoinRequestsHost({
    super.key,
    required this.livestreamId,
    this.top = 64,
  });

  @override
  State<LiveJoinRequestsHost> createState() => _LiveJoinRequestsHostState();
}

class _LiveJoinRequestsHostState extends State<LiveJoinRequestsHost> {
  /// Waiting requests, oldest first.
  final List<_JoinReq> _pending = [];
  final Set<String> _busy = {};
  final ValueNotifier<int> _version = ValueNotifier(0);

  String get _base => '/api/v1/live/${widget.livestreamId}';
  String get _channel => 'live.${widget.livestreamId}.join';

  @override
  void initState() {
    super.initState();
    final pusher = sl<PusherService>();
    pusher.subscribe(_channel);
    pusher.bind(_channel, 'join.created', _onCreated);
    pusher.bind(_channel, 'join.decided', _onDecided);
    _loadPending();
  }

  @override
  void dispose() {
    final pusher = sl<PusherService>();
    pusher.unbind(_channel, 'join.created', _onCreated);
    pusher.unbind(_channel, 'join.decided', _onDecided);
    _version.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _version.value++;
  }

  Future<void> _loadPending() async {
    try {
      final res = await sl<DioClient>().dio.get('$_base/join-requests');
      final list = ((res.data as Map)['data'] as List?) ?? const [];
      for (final m in list) {
        _add(_JoinReq.fromJson(m as Map), quiet: true);
      }
      _changed();
    } catch (_) {}
  }

  void _onCreated(Map<String, dynamic> m) => _add(_JoinReq.fromJson(m));

  // Accepted / declined (maybe from another device) or cancelled by the
  // viewer → drop it.
  void _onDecided(Map<String, dynamic> m) {
    final id = m['id']?.toString();
    _pending.removeWhere((r) => r.id == id);
    _changed();
  }

  void _add(_JoinReq r, {bool quiet = false}) {
    if (r.id.isEmpty || _pending.any((x) => x.id == r.id)) return;
    _pending.add(r);
    if (!quiet) {
      HapticFeedback.mediumImpact();
      _changed();
    }
  }

  Future<void> _decide(_JoinReq r, bool approve) async {
    if (_busy.contains(r.id)) return;
    _busy.add(r.id);
    _changed();
    try {
      await sl<DioClient>().dio.post(
        '$_base/join/${r.id}/${approve ? 'accept' : 'decline'}',
      );
      _pending.removeWhere((x) => x.id == r.id);
      if (approve && mounted) {
        TopSnack.success(context, '${r.name} joined the box 🎉');
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Couldn\'t update the request.';
        if (e is DioException) {
          final d = e.response?.data;
          if (d is Map && d['message'] is String) msg = d['message'];
        }
        TopSnack.error(context, msg);
      }
    } finally {
      _busy.remove(r.id);
      _changed();
    }
  }

  void _openList() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14101F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => ValueListenableBuilder<int>(
        valueListenable: _version,
        builder: (c, _, _) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(c).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                  child: Row(
                    children: [
                      const Text(
                        'Join requests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CountBadge(_pending.length),
                    ],
                  ),
                ),
                if (_pending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'No one is waiting right now',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        for (final r in _pending)
                          _RequestRow(
                            req: r,
                            busy: _busy.contains(r.id),
                            onAccept: () => _decide(r, true),
                            onDecline: () => _decide(r, false),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + widget.top;
    final r = _pending.isEmpty ? null : _pending.last;
    return Positioned(
      top: top,
      left: 12,
      right: 150, // keep clear of the guest column on the right
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, a) => SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.4),
            end: Offset.zero,
          ).animate(a),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: r == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : _RequestFlag(
                key: ValueKey(r.id),
                req: r,
                more: _pending.length - 1,
                busy: _busy.contains(r.id),
                onAccept: () => _decide(r, true),
                onDecline: () => _decide(r, false),
                onOpenList: _openList,
              ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final _JoinReq req;
  final double radius;
  const _Avatar(this.req, {this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final has = req.avatar.startsWith('http');
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF221D44),
      backgroundImage: has ? NetworkImage(req.avatar) : null,
      child: has
          ? null
          : Text(
              req.name.isNotEmpty ? req.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int n;
  const _CountBadge(this.n);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFFF2D55),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$n',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final bool primary;
  final VoidCallback? onTap;
  const _RoundAction({required this.icon, this.primary = false, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: primary
            ? const LinearGradient(
                colors: [Color(0xFFFF2D55), Color(0xFFFF7A00)],
              )
            : null,
        color: primary ? null : Colors.white.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

/// Compact flag for the newest request.
class _RequestFlag extends StatelessWidget {
  final _JoinReq req;
  final int more;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpenList;

  const _RequestFlag({
    super.key,
    required this.req,
    required this.more,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onOpenList,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onOpenList,
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFFF2D55).withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Avatar(req),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      req.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      more > 0
                          ? 'wants to join · +$more more'
                          : 'wants to join',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(7),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              else ...[
                _RoundAction(icon: Icons.close_rounded, onTap: onDecline),
                const SizedBox(width: 6),
                _RoundAction(
                  icon: Icons.check_rounded,
                  primary: true,
                  onTap: onAccept,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final _JoinReq req;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestRow({
    required this.req,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _Avatar(req, radius: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              req.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else ...[
            TextButton(
              onPressed: onDecline,
              child: const Text(
                'Decline',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onAccept,
              child: const Text('Approve'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Host taps a guest tile: send them back to watching, or remove them.
Future<void> showHostGuestActions(
  BuildContext context, {
  required int livestreamId,
  required LiveGuest guest,
  required VoidCallback onChanged,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF14101F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Text(
            guest.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.white),
            title: const Text(
              'Remove from the box',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'They go back to watching',
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () => Navigator.pop(c, 'box'),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
            title: const Text(
              'Remove from the live',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () => Navigator.pop(c, 'live'),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  final base = '/api/v1/live/$livestreamId/participants/${guest.uuid}';
  try {
    if (choice == 'box') {
      await sl<DioClient>().dio.post('$base/role', data: {'role': 'viewer'});
    } else {
      await sl<DioClient>().dio.post('$base/remove');
    }
    onChanged();
  } catch (_) {
    if (context.mounted) {
      TopSnack.error(context, 'Couldn\'t update ${guest.name}. Try again.');
    }
  }
}
