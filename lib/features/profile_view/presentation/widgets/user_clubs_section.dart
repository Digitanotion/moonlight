// lib/features/profile_view/presentation/widgets/user_clubs_section.dart
//
// Displays the clubs a user belongs to on their profile page.
// Call this widget from your profile screen, passing the user's UUID.
// It self-fetches clubs via ProfileRepository and handles all states.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/profile_view/domain/repositories/profile_repository.dart';

class UserClubsSection extends StatefulWidget {
  final String userUuid;

  /// Reports the number of clubs once loaded, so a parent screen
  /// (e.g. a tab bar showing "Clubs (2)") can reflect it without
  /// this widget needing to know anything about that UI.
  final ValueChanged<int>? onCountLoaded;

  const UserClubsSection({
    super.key,
    required this.userUuid,
    this.onCountLoaded,
  });

  @override
  State<UserClubsSection> createState() => _UserClubsSectionState();
}

class _UserClubsSectionState extends State<UserClubsSection> {
  List<ProfileClub>? _clubs;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final repo = GetIt.I<ProfileRepository>();
      final clubs = await repo.getUserClubs(widget.userUuid);
      if (mounted) {
        setState(() {
          _clubs = clubs;
          _loading = false;
        });
      }
      widget.onCountLoaded?.call(clubs.length);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
      widget.onCountLoaded?.call(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFF6A00),
            ),
          ),
        ),
      );
    }

    if (_error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFF8B8FB8), size: 28),
              const SizedBox(height: 8),
              const Text(
                "Couldn't load clubs",
                style: TextStyle(color: Color(0xFF8B8FB8), fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _fetch();
                },
                child: const Text('Retry',
                    style: TextStyle(color: Color(0xFFFF6A00))),
              ),
            ],
          ),
        ),
      );
    }

    if (_clubs == null || _clubs!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: Text(
            'No clubs yet',
            style: TextStyle(color: Color(0xFF8B8FB8), fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Row(
            children: [
              const Text(
                'Clubs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_clubs!.length}',
                style: const TextStyle(
                  color: Color(0xFF8B8FB8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _clubs!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _ClubCard(club: _clubs![i]),
        ),
      ],
    );
  }
}

class _ClubCard extends StatelessWidget {
  final ProfileClub club;
  const _ClubCard({required this.club});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (club.avatarUrl ?? '').isNotEmpty &&
        Uri.tryParse(club.avatarUrl!)?.hasScheme == true;
    final roleLabel = club.roleBadgeLabel;
    final subtitle = (club.motto ?? '').isNotEmpty
        ? club.motto!
        : (club.description ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(
          context,
          RouteNames.clubProfile,
          arguments: {'clubUuid': club.uuid, 'club_slug': club.slug},
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Club cover image
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF1A1D3D),
                    width: 1.5,
                  ),
                  color: const Color(0xFF0E1024),
                ),
                child: ClipOval(
                  child: hasAvatar
                      ? CachedNetworkImage(
                          imageUrl: club.avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const _ClubPlaceholder(),
                          errorWidget: (_, __, ___) =>
                              const _ClubPlaceholder(),
                        )
                      : const _ClubPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            club.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (club.isPrivate) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: Color(0xFF8B8FB8),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8B8FB8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (roleLabel != null) ...[
                          _RoleBadge(label: roleLabel),
                          const SizedBox(width: 8),
                        ],
                        Icon(
                          Icons.groups_rounded,
                          size: 13,
                          color: const Color(0xFF8B8FB8).withOpacity(0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatCount(club.membersCount)} members',
                          style: const TextStyle(
                            color: Color(0xFF8B8FB8),
                            fontSize: 11.5,
                          ),
                        ),
                        if ((club.location ?? '').isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.place_outlined,
                            size: 13,
                            color: Color(0xFF8B8FB8),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              club.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF8B8FB8),
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8B8FB8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// Small pill badge shown for "Creator" or "Admin" roles.
/// Creator gets an accent color to stand out from Admin.
class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final isCreator = label == 'Creator';
    final color = isCreator ? const Color(0xFFFF7A00) : const Color(0xFF4C6FFF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCreator ? Icons.star_rounded : Icons.shield_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubPlaceholder extends StatelessWidget {
  const _ClubPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFFF6A00).withOpacity(0.15),
        child: const Icon(Icons.groups_rounded,
            size: 24, color: Color(0xFFFF6A00)),
      );
}