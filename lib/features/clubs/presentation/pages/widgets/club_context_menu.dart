import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart';

import 'members_bottom_sheet.dart';
import 'create_edit_club_sheet.dart';
import 'add_member_sheet.dart';
import 'delete_club_dialog.dart';

class ClubContextMenu extends StatelessWidget {
  final Club club;

  const ClubContextMenu({super.key, required this.club});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert, color: Colors.white70),
      color: const Color(0xFF0A0A0F),
      onSelected: (v) async {
        switch (v) {
          case 1:
            showMembersSheet(context, club.slug);
            break;
          case 2:
            await showCreateEditClubSheet(context, club: club);
            context.read<MyClubsCubit>().refresh();
            break;
          case 3:
            showAddMemberSheet(context, club.slug);
            break;
          case 4:
            await showDeleteClubDialog(context, club.slug);
            context.read<MyClubsCubit>().refresh();
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 1,
          child: Text('Members', style: TextStyle(color: Colors.white)),
        ),
        if (club.isCreator) ...[
          const PopupMenuItem(
            value: 2,
            child: Text('Edit Club', style: TextStyle(color: Colors.white)),
          ),
          const PopupMenuItem(
            value: 3,
            child: Text('Add Member', style: TextStyle(color: Colors.white)),
          ),
          const PopupMenuItem(
            value: 4,
            child: Text('Delete Club', style: TextStyle(color: Colors.red)),
          ),
        ],
      ],
    );
  }
}
