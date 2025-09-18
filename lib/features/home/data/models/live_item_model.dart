import 'package:moonlight/core/utils/countries.dart';

import '../../domain/entities/live_item.dart';

class LiveItemModel extends LiveItem {
  LiveItemModel({
    required super.id,
    required super.uuid,
    required super.channel,
    required super.coverUrl,
    required super.handle,
    required super.role,
    required super.countryIso2,
    required super.countryName,
    required super.viewers,
    required super.title,
    required super.startedAt,
  });

  factory LiveItemModel.fromJson(Map<String, dynamic> j) {
    final host = (j['host'] ?? {}) as Map<String, dynamic>;
    final slug = (host['user_slug'] as String?) ?? 'unknown';
    final handle = '@$slug'; // <— requirement: @user_slug

    // API can send "KENYA" (name) — normalize to ISO2
    final rawCountry = host['country'] as String?;
    final iso2 = normalizeCountryToIso2(rawCountry) ?? 'NG';
    final name = countryDisplayName(iso2);

    return LiveItemModel(
      id: (j['id'] as num).toInt(),
      uuid: j['uuid'] as String,
      channel: j['channel'] as String,
      coverUrl: j['cover_url'] as String?,
      handle: handle,
      role: (host['rank_tag'] as String?) ?? 'Host',
      countryIso2: iso2,
      countryName: name,
      viewers: (j['viewers'] as num?)?.toInt() ?? 0,
      title: j['title'] as String,
      startedAt: j['started_at'] as String,
    );
  }
}
