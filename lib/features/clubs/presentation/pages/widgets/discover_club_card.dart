import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/delete_club_dialog.dart';

class DiscoverClubCard extends StatelessWidget {
  final Club club;
  final bool joining;
  final VoidCallback onJoin;

  final bool compact;

  const DiscoverClubCard({
    super.key,
    required this.club,
    required this.joining,
    required this.onJoin,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final joined = club.isMember;
    final isAdmin = club.isCreator;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(
            context,
            RouteNames.clubProfile,
            arguments: {'clubUuid': club.uuid},
          );
        },
        child: Row(
          children: [
            _Avatar(club.coverImageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Text(club.isCreator.toString()),
                  Text(
                    '${club.membersCount} members · Active 2h ago',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 6),
                    _rolePill('Admin'),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            /// ================= RIGHT ACTION =================
            if (isAdmin) _ManageButton(onTap: () => _showManageSheet(context)),
            // else
            //   _JoinButton(
            //     joined: joined,
            //     joining: joining,
            //     onPressed: joined ? null : onJoin,
            //   ),
          ],
        ),
      ),
    );
  }

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
              _sheetItem(
                icon: Icons.info_outline,
                label: 'Club Info',
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    RouteNames.clubProfile,
                    arguments: {'clubUuid': club.uuid},
                  );
                },
              ),
              _sheetItem(
                icon: Icons.edit,
                label: 'Edit Club Information',
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
                icon: Icons.group,
                label: 'Members',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    RouteNames.clubMembers,
                    arguments: {
                      'club': club.slug ?? club.uuid, // ← IMPORTANT
                    },
                  );
                },
              ),

              _sheetItem(
                icon: Icons.delete_outline,
                label: 'Delete Club',
                destructive: true,
                onTap: () async {
                  Navigator.pop(context);
                  await showDeleteClubDialog(context, club.slug);
                  // context. read<MyClubsCubit>().refresh();
                  // Deletion confirmation comes in Phase 3.1
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
    return ListTile(
      leading: Icon(
        icon,
        color: destructive ? Colors.redAccent : Colors.white70,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: destructive ? Colors.redAccent : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _rolePill(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.info,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/* ======================= AVATAR ======================= */

class _Avatar extends StatelessWidget {
  final String? url;
  const _Avatar(this.url);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: Colors.white10,
        backgroundImage: (url != null && url!.startsWith('http'))
            ? NetworkImage(url!)
            : null,
        child: url == null
            ? const Icon(Icons.groups, color: Colors.white54)
            : null,
      ),
    );
  }
}

/* ======================= MANAGE ======================= */

class _ManageButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ManageButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Manage',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/* ======================= JOIN ======================= */

class _JoinButton extends StatelessWidget {
  final bool joined;
  final bool joining;
  final VoidCallback? onPressed;

  const _JoinButton({
    required this.joined,
    required this.joining,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (joined) {
      return _pill(
        label: 'Joined Club',
        color: Colors.white24,
        textColor: Colors.white70,
      );
    }

    return GestureDetector(
      onTap: joining ? null : onPressed,
      child: _pill(
        label: joining ? 'Joining…' : 'Join',
        color: const Color(0xFFFF7A00),
        textColor: Colors.white,
      ),
    );
  }

  Widget _pill({
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
