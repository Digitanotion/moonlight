import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/domain/entities/club_member.dart';
import '../../cubit/club_members_cubit.dart';

class ClubMemberCard extends StatelessWidget {
  final ClubMember member;

  const ClubMemberCard({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF121A4A), Color(0xFF0D133A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              /// ───── Avatar → Profile View ─────
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (member.isSelf) return;
                  Navigator.pushNamed(
                    context,
                    RouteNames.profileView,
                    arguments: {'userUuid': member.uuid},
                  );
                },
                child: CircleAvatar(
                  radius: 26,
                  backgroundImage: member.avatarUrl != null
                      ? NetworkImage(member.avatarUrl!)
                      : null,
                  backgroundColor: Colors.deepPurple,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullname,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Joined ${member.joinedDaysAgo} days ago',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              /// ───── Context Menu ─────
              if (member.canPromote || member.canDemote || member.canRemove)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _showMenu(context, details),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.more_vert, color: Colors.white54),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            children: [
              if (member.isOwner) const _Tag('President'),
              if (member.isAdmin) const _Tag('Admin'),
              if (!member.isOwner && !member.isAdmin) const _Tag('Active'),
            ],
          ),
        ],
      ),
    );
  }

  /// ───────────────── CONTEXT MENU ─────────────────

  void _showMenu(BuildContext context, TapDownDetails details) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final action = await showMenu<_MemberAction>(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: _menuItems(),
    );

    if (action != null) {
      _handleAction(context, action);
    }
  }

  List<PopupMenuEntry<_MemberAction>> _menuItems() {
    final items = <PopupMenuEntry<_MemberAction>>[];

    if (member.canPromote) {
      items.add(
        const PopupMenuItem(
          value: _MemberAction.promote,
          child: Text('Make Admin'),
        ),
      );
    }

    if (member.canDemote) {
      items.add(
        const PopupMenuItem(
          value: _MemberAction.demote,
          child: Text('Remove as Admin'),
        ),
      );
    }

    if (member.canRemove) {
      items.add(
        const PopupMenuItem(
          value: _MemberAction.remove,
          child: Text(
            'Remove from Club',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    return items;
  }

  /// ───────────────── ACTION HANDLER ─────────────────

  void _handleAction(BuildContext context, _MemberAction action) {
    final cubit = context.read<ClubMembersCubit>();

    switch (action) {
      case _MemberAction.promote:
        cubit.promote(member.uuid);
        break;

      case _MemberAction.demote:
        cubit.demote(member.uuid);
        break;

      case _MemberAction.remove:
        _confirmRemove(context, cubit);
        break;
    }
  }

  /// ───────────────── CONFIRM + FEEDBACK ─────────────────

  void _confirmRemove(BuildContext context, ClubMembersCubit cubit) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove member'),
        content: Text(
          'Are you sure you want to remove ${member.fullname} from this club?',
        ),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);

              try {
                await cubit.remove(member.uuid);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Member removed successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to remove member. Please try again.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

enum _MemberAction { promote, demote, remove }

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A78),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
