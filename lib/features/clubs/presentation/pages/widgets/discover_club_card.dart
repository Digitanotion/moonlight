import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/delete_club_dialog.dart';

/// The shared full-width club row — used for "My Clubs" and for search
/// results on the Discover screen.
///
/// Layout: cover thumbnail · name + member count + role chip · trailing
/// action. The trailing action is context-aware:
///   * club owner  → "Manage" (opens the manage sheet)
///   * not a member → "Join"  (calls [onJoin], shows a spinner while [joining])
///   * member       → a chevron
class DiscoverClubCard extends StatelessWidget {
  final Club club;
  final bool joining;
  final VoidCallback onJoin;

  /// Tighter paddings + no description, for narrow / horizontal contexts.
  final bool compact;

  const DiscoverClubCard({
    super.key,
    required this.club,
    required this.joining,
    required this.onJoin,
    this.compact = false,
  });

  void _openProfile(BuildContext context) {
    Navigator.pushNamed(
      context,
      RouteNames.clubProfile,
      arguments: {'clubUuid': club.uuid},
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = compact ? 12.0 : 14.0;
    final thumb = compact ? 44.0 : 54.0;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openProfile(context),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: EdgeInsets.all(pad),
          child: Row(
            children: [
              _Thumb(url: club.coverImageUrl, size: thumb),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            club.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 14 : 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (club.isPrivate) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _members(club.membersCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_role != null) ...[_dot(), _RoleChip(role: _role!)],
                      ],
                    ),
                    if (!compact &&
                        (club.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        club.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _trailing(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    if (club.isCreator) {
      return _ActionPill(
        label: 'Manage',
        filled: true,
        onTap: () => _showManageSheet(context),
      );
    }
    if (!club.isMember) {
      return _ActionPill(
        label: joining ? '' : 'Join',
        filled: true,
        busy: joining,
        onTap: joining ? null : onJoin,
      );
    }
    return Icon(
      Icons.chevron_right_rounded,
      color: Colors.white.withOpacity(0.3),
      size: 22,
    );
  }

  String? get _role {
    if (club.isCreator) return 'Owner';
    if (club.isAdmin) return 'Admin';
    if (club.isMember) return 'Member';
    return null;
  }

  Widget _dot() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 7),
    width: 3,
    height: 3,
    decoration: BoxDecoration(
      color: AppColors.secondaryText,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  static String _members(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M members';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K members';
    return '$n member${n == 1 ? '' : 's'}';
  }

  // ── Manage sheet (owner) ───────────────────────────────────────────────

  void _showManageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              _sheetItem(
                icon: Icons.info_outline_rounded,
                label: 'Club info',
                onTap: () {
                  Navigator.pop(context);
                  _openProfile(context);
                },
              ),
              _sheetItem(
                icon: Icons.edit_outlined,
                label: 'Edit club information',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    RouteNames.updateClub,
                    arguments: {'clubUuid': club.uuid},
                  );
                },
              ),
              _sheetItem(
                icon: Icons.group_outlined,
                label: 'Members',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    RouteNames.clubMembers,
                    arguments: {
                      'club': club.slug.isNotEmpty ? club.slug : club.uuid,
                    },
                  );
                },
              ),
              _sheetItem(
                icon: Icons.delete_outline_rounded,
                label: 'Delete club',
                destructive: true,
                onTap: () async {
                  Navigator.pop(context);
                  await showDeleteClubDialog(context, club.slug);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? const Color(0xFFFF6B6B) : Colors.white;
    return ListTile(
      leading: Icon(icon, color: destructive ? color : Colors.white70),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      onTap: onTap,
    );
  }
}

/* ───────────────────────────── thumb ───────────────────────────── */

class _Thumb extends StatelessWidget {
  final String? url;
  final double size;
  const _Thumb({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final has = (url ?? '').startsWith('http');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2A6B), Color(0xFF0B1230)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: has
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _icon(),
              placeholder: (_, _) => _icon(),
            )
          : _icon(),
    );
  }

  Widget _icon() => Center(
    child: Icon(
      Icons.groups_2_rounded,
      color: Colors.white.withOpacity(0.35),
      size: size * 0.5,
    ),
  );
}

/* ───────────────────────────── role chip ───────────────────────────── */

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (role) {
      'Owner' => (AppColors.secondary.withOpacity(0.16), AppColors.secondary),
      'Admin' => (AppColors.info.withOpacity(0.16), AppColors.info),
      _ => (Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.65)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/* ───────────────────────────── action pill ───────────────────────────── */

class _ActionPill extends StatelessWidget {
  final String label;
  final bool filled;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionPill({
    required this.label,
    required this.filled,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        constraints: const BoxConstraints(minWidth: 64),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: filled ? AppColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: filled
              ? null
              : Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: busy
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
