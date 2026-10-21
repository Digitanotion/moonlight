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

/// Invisible helper that lives on the host screen and shows the pop-ups.
class LiveJoinRequestsHost extends StatefulWidget {
  final int livestreamId;
  const LiveJoinRequestsHost({super.key, required this.livestreamId});

  @override
  State<LiveJoinRequestsHost> createState() => _LiveJoinRequestsHostState();
}

class _LiveJoinRequestsHostState extends State<LiveJoinRequestsHost> {
  final List<_JoinReq> _queue = [];
  final Set<String> _seen = {};
  bool _showing = false;

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
    super.dispose();
  }

  Future<void> _loadPending() async {
    try {
      final res = await sl<DioClient>().dio.get('$_base/join-requests');
      final list = ((res.data as Map)['data'] as List?) ?? const [];
      for (final m in list) {
        _enqueue(_JoinReq.fromJson(m as Map));
      }
    } catch (_) {}
  }

  void _onCreated(Map<String, dynamic> m) => _enqueue(_JoinReq.fromJson(m));

  // Cancelled by the viewer → drop it from the queue.
  void _onDecided(Map<String, dynamic> m) {
    final id = m['id']?.toString();
    _queue.removeWhere((r) => r.id == id);
  }

  void _enqueue(_JoinReq r) {
    if (r.id.isEmpty || !_seen.add(r.id)) return;
    _queue.add(r);
    _next();
  }

  Future<void> _next() async {
    if (_showing || _queue.isEmpty || !mounted) return;
    _showing = true;
    final r = _queue.removeAt(0);
    HapticFeedback.mediumImpact();
    final approve = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (c) => _RequestDialog(req: r, waiting: _queue.length),
    );
    if (approve != null && mounted) await _decide(r, approve);
    _showing = false;
    if (mounted) _next();
  }

  Future<void> _decide(_JoinReq r, bool approve) async {
    try {
      await sl<DioClient>().dio.post(
        '$_base/join/${r.id}/${approve ? 'accept' : 'decline'}',
      );
      if (approve && mounted) {
        TopSnack.success(context, '${r.name} joined the box 🎉');
      }
    } catch (e) {
      if (!mounted) return;
      String msg = 'Couldn\'t update the request.';
      if (e is DioException) {
        final d = e.response?.data;
        if (d is Map && d['message'] is String) msg = d['message'];
      }
      TopSnack.error(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _RequestDialog extends StatelessWidget {
  final _JoinReq req;
  final int waiting;
  const _RequestDialog({required this.req, required this.waiting});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = req.avatar.startsWith('http');
    return Dialog(
      backgroundColor: const Color(0xFF14101F),
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFF2D55), Color(0xFFFF7A00)],
                ),
              ),
              child: CircleAvatar(
                radius: 38,
                backgroundColor: const Color(0xFF221D44),
                backgroundImage: hasAvatar ? NetworkImage(req.avatar) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        req.name.isNotEmpty ? req.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              req.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'wants to join you on camera',
              style: TextStyle(color: Colors.white60),
            ),
            if (waiting > 0) ...[
              const SizedBox(height: 6),
              Text(
                '+$waiting more waiting',
                style: const TextStyle(color: Color(0xFFFF7A00), fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Approve',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
