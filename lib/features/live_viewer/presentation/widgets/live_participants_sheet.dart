// lib/features/live_viewer/presentation/widgets/live_participants_sheet.dart
//
// A lightly-translucent sheet listing everyone watching the current live
// stream. Deliberately see-through (blurred dark scrim) so the host's
// video stays visible behind it. Each row has a compact Follow control
// that collapses to a check the moment you follow.

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';

class LiveParticipantsSheet extends StatefulWidget {
  final String livestreamParam;
  final int? viewerCount;

  const LiveParticipantsSheet({
    super.key,
    required this.livestreamParam,
    this.viewerCount,
  });

  static Future<void> show(
    BuildContext context, {
    required String livestreamParam,
    int? viewerCount,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.15), // keep the stream visible
      builder: (_) => LiveParticipantsSheet(
        livestreamParam: livestreamParam,
        viewerCount: viewerCount,
      ),
    );
  }

  @override
  State<LiveParticipantsSheet> createState() => _LiveParticipantsSheetState();
}

class _LiveParticipantsSheetState extends State<LiveParticipantsSheet> {
  final _dio = sl<DioClient>();
  List<_Participant> _people = [];
  bool _loading = true;
  String? _error;
  String? _myUuid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _myUuid = await sl<AuthLocalDataSource>().getCurrentUserUuid();
      final res = await _dio.dio.get(
        '/api/v1/live/${widget.livestreamParam}/participants',
      );
      final data = res.data is Map ? res.data as Map : <String, dynamic>{};
      final list = (data['data'] as List? ?? [])
          .whereType<Map>()
          .map((m) => _Participant.fromJson(m.cast<String, dynamic>()))
          .toList();
      // Host first, then everyone else.
      list.sort((a, b) {
        if (a.role == 'host' && b.role != 'host') return -1;
        if (b.role == 'host' && a.role != 'host') return 1;
        return 0;
      });
      if (!mounted) return;
      setState(() {
        _people = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load participants';
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow(_Participant p) async {
    final wasFollowing = p.following;
    setState(() => p.following = !wasFollowing);
    try {
      if (wasFollowing) {
        await _dio.dio.delete('/api/v1/users/${p.uuid}/follow');
      } else {
        await _dio.dio.post('/api/v1/users/${p.uuid}/follow');
      }
    } catch (_) {
      if (mounted) setState(() => p.following = wasFollowing); // rollback
    }
  }

  void _openProfile(_Participant p) {
    Navigator.of(context).pop();
    Navigator.pushNamed(
      context,
      RouteNames.profileView,
      arguments: {'userUuid': p.uuid, 'user_slug': p.slug},
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B1024).withOpacity(0.62),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.10)),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.remove_red_eye_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Watching now',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.viewerCount ?? _people.length}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: Colors.white.withOpacity(0.08), height: 1),
                  Expanded(child: _body(scrollCtrl)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(ScrollController scrollCtrl) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              child: const Text('Retry',
                  style: TextStyle(color: AppColors.secondary)),
            ),
          ],
        ),
      );
    }
    if (_people.isEmpty) {
      return const Center(
        child: Text('No one else is here yet',
            style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.separated(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _people.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (_, i) => _row(_people[i]),
    );
  }

  Widget _row(_Participant p) {
    final isMe = _myUuid != null && p.uuid == _myUuid;
    return InkWell(
      onTap: () => _openProfile(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: p.role == 'host'
                      ? AppColors.secondary.withOpacity(0.8)
                      : Colors.white.withOpacity(0.14),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: p.avatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: p.avatar,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.person, color: Colors.white38, size: 20),
                      )
                    : const Icon(Icons.person, color: Colors.white38, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.slug.isNotEmpty ? p.slug : 'Guest',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (p.role == 'host' || p.role == 'cohost') ...[
                        const SizedBox(width: 6),
                        _roleTag(p.role),
                      ],
                    ],
                  ),
                  if (isMe)
                    Text('You',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ],
              ),
            ),
            if (!isMe) _followControl(p),
          ],
        ),
      ),
    );
  }

  Widget _roleTag(String role) {
    final label = role == 'host' ? 'HOST' : 'CO-HOST';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.secondary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _followControl(_Participant p) {
    if (p.following) {
      return GestureDetector(
        onTap: () => _toggleFollow(p),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.28)),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _toggleFollow(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.chatOutgoingTop, AppColors.chatOutgoingBottom],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Follow',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Participant {
  final String uuid;
  final String slug;
  final String avatar;
  final String role;
  bool following;

  _Participant({
    required this.uuid,
    required this.slug,
    required this.avatar,
    required this.role,
    required this.following,
  });

  factory _Participant.fromJson(Map<String, dynamic> j) {
    bool follows = false;
    for (final key in ['followed_by_me', 'is_following', 'following']) {
      final v = j[key];
      if (v is bool) follows = v;
      if (v is String) follows = v.toLowerCase() == 'true';
    }
    return _Participant(
      uuid: (j['user_uuid'] ?? j['uuid'] ?? '').toString(),
      slug: (j['user_slug'] ?? j['username'] ?? j['name'] ?? '').toString(),
      avatar: (j['avatar'] ?? j['avatar_url'] ?? '').toString(),
      role: (j['role'] ?? 'viewer').toString(),
      following: follows,
    );
  }
}
