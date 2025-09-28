import 'dart:async';
import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/participant.dart';
import '../../domain/entities/paginated.dart';
import '../../domain/repositories/participants_repository.dart';

class ParticipantsRepositoryImpl implements ParticipantsRepository {
  final DioClient _client;
  final PusherService _pusher;
  @override
  final int livestreamIdNumeric;
  @override
  final String livestreamParam;

  ParticipantsRepositoryImpl(
    this._client,
    this._pusher, {
    required this.livestreamIdNumeric,
    required this.livestreamParam,
  });

  final _addedCtrl = StreamController<Participant>.broadcast();
  final _removedCtrl = StreamController<String>.broadcast();
  final _roleChangedCtrl =
      StreamController<MapEntry<String, String>>.broadcast();

  bool _socketBound = false;

  @override
  Future<Paginated<Participant>> list({int page = 1, String? role}) async {
    final res = await _client.dio.get(
      '/api/v1/live/$livestreamParam/participants',
      queryParameters: {
        'page': page,
        if (role != null && role.isNotEmpty) 'role': role,
      },
    );
    final data = (res.data is Map) ? res.data as Map : const {};
    final items = (data['data'] as List? ?? [])
        .cast<Map>()
        .map(_fromJson)
        .toList();

    return Paginated<Participant>(
      data: items,
      currentPage: (data['current_page'] ?? 1) as int,
      lastPage: (data['last_page'] ?? 1) as int,
      perPage: int.tryParse('${data['per_page'] ?? 50}') ?? 50,
      total: (data['total'] ?? items.length) as int,
      nextPageUrl: data['next_page_url'] as String?,
    );
  }

  @override
  Future<Participant> changeRole(String userUuid, String role) async {
    // NOTE: Guide has a "quest" typo — use "guest"
    final res = await _client.dio.post(
      '/api/v1/live/$livestreamParam/participants/$userUuid/role',
      data: {'role': role},
    );
    final m = (res.data is Map)
        ? (res.data as Map).cast<String, dynamic>()
        : {};
    // We may not get all fields back, so up to UI to merge. For safety:
    return Participant(
      userUuid: (m['user_uuid'] ?? userUuid).toString(),
      userSlug: (m['user_slug'] ?? '').toString(),
      avatar: null,
      role: (m['role'] ?? role).toString(),
      joinedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> remove(String userUuid) async {
    await _client.dio.post(
      '/api/v1/live/$livestreamParam/participants/$userUuid/remove',
    );
  }

  Participant _fromJson(Map raw) {
    final m = raw.cast<String, dynamic>();
    return Participant(
      userUuid: (m['user_uuid'] ?? '').toString(),
      userSlug: (m['user_slug'] ?? '').toString(),
      avatar: (m['avatar']?.toString().isNotEmpty ?? false)
          ? m['avatar'].toString()
          : null,
      role: (m['role'] ?? 'audience').toString(),
      joinedAt:
          DateTime.tryParse('${m['joined_at']}')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  void _bindSocketsIfNeeded() {
    if (_socketBound) return;
    _socketBound = true;

    final metaCh = 'live.$livestreamIdNumeric.meta';
    final viewerCh = 'live.$livestreamIdNumeric.viewer'; // present in guide
    final rootCh = 'live.$livestreamIdNumeric';

    // Ensure we’re on these channels
    _pusher.subscribe(metaCh);
    _pusher.subscribe(viewerCh);
    _pusher.subscribe(rootCh);

    Map<String, dynamic> _norm(dynamic raw) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return raw.cast<String, dynamic>();
      return {};
    }

    void bind(String ch, List<String> events, void Function(Map) cb) {
      for (final e in events) {
        _pusher.bind(ch, e, (m) => cb(_norm(m)));
      }
    }

    // participant.added — guide: broadcast on meta/viewer; bind to both
    void onAdded(Map m) {
      // The payload looks like:
      // { user_uuid, user_slug, avatar, role, at }
      final uuid = (m['user_uuid'] ?? '').toString();
      if (uuid.isEmpty) return;
      final p = Participant(
        userUuid: uuid,
        userSlug: (m['user_slug'] ?? '').toString(),
        avatar: (m['avatar']?.toString().isNotEmpty ?? false)
            ? m['avatar'].toString()
            : null,
        role: (m['role'] ?? 'audience').toString(),
        joinedAt:
            DateTime.tryParse('${m['at']}')?.toUtc() ?? DateTime.now().toUtc(),
      );
      _addedCtrl.add(p);
    }

    bind(metaCh, [
      'participant.added',
      'App\\Events\\ParticipantAdded',
    ], onAdded);
    bind(viewerCh, [
      'participant.added',
      'App\\Events\\ParticipantAdded',
    ], onAdded);

    // participants.removed (guide says broadcast “participants.removed”)
    void onRemoved(Map m) {
      final uuid = (m['user_uuid'] ?? '').toString();
      if (uuid.isEmpty) return;
      _removedCtrl.add(uuid);
    }

    bind(metaCh, [
      'participants.removed',
      'App\\Events\\ParticipantRemoved',
    ], onRemoved);
    bind(viewerCh, [
      'participants.removed',
      'App\\Events\\ParticipantRemoved',
    ], onRemoved);

    // participant.role_changed
    void onRoleChanged(Map m) {
      final uuid = (m['user_uuid'] ?? '').toString();
      final role = (m['role'] ?? '').toString();
      if (uuid.isEmpty || role.isEmpty) return;
      _roleChangedCtrl.add(MapEntry(uuid, role));
    }

    bind(metaCh, [
      'participant.role_changed',
      'App\\Events\\ParticipantRoleChanged',
    ], onRoleChanged);
  }

  @override
  Stream<Participant> participantAddedStream() {
    _bindSocketsIfNeeded();
    return _addedCtrl.stream;
  }

  @override
  Stream<String> participantRemovedStream() {
    _bindSocketsIfNeeded();
    return _removedCtrl.stream;
  }

  @override
  Stream<MapEntry<String, String>> roleChangedStream() {
    _bindSocketsIfNeeded();
    return _roleChangedCtrl.stream;
  }

  @override
  Future<void> dispose() async {
    await _addedCtrl.close();
    await _removedCtrl.close();
    await _roleChangedCtrl.close();
    // We intentionally do NOT unsubscribe global live.* channels here,
    // because LiveHostPage is probably still using them.
  }
}
