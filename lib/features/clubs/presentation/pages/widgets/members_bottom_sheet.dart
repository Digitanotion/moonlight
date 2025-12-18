import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/widgets/safe_avatar.dart';
import 'package:moonlight/features/clubs/domain/entities/club_member.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_members_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_members_state.dart';

void showMembersSheet(BuildContext context, String club) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0A0A0F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return BlocProvider(
        create: (_) =>
            ClubMembersCubit(repo: sl<ClubsRepository>(), club: club)..load(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: const _MembersSheet(),
        ),
      );
    },
  );
}

class _MembersSheet extends StatelessWidget {
  const _MembersSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClubMembersCubit, ClubMembersState>(
      builder: (context, state) {
        // print('🎯 UI: Building with state:');
        // print('  - Loading: ${state.loading}');
        // print('  - Error: ${state.error}');
        // print('  - Members count: ${state.members.length}');
        // print('  - Club: ${state.club?.name}');

        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.error != null) {
          return Center(
            child: Text(
              'Error: ${state.error}',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        if (state.members.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group, size: 48, color: Colors.white54),
                SizedBox(height: 16),
                Text('No members found', style: TextStyle(color: Colors.white)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.members.length,
          itemBuilder: (_, i) {
            final member = state.members[i]; // Renamed for clarity
            return ListTile(
              leading: SafeAvatar(url: member.avatarUrl, radius: 20),
              title: Text(
                member.fullname,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${member.isOwner ? 'CREATOR ' : 'MEMBER '}${member.isAdmin ? '& ADMIN' : ''}',
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: _MemberActions(member), // Pass ClubMember, not dynamic
            );
          },
        );
      },
    );
  }
}

// Update _MemberActions to use proper type
class _MemberActions extends StatelessWidget {
  final ClubMember member; // Changed from dynamic to ClubMember

  const _MemberActions(this.member);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_horiz, color: Colors.white54),
      onSelected: (v) {
        final cubit = context.read<ClubMembersCubit>();

        if (v == 1 && member.canPromote) {
          cubit.promote(member.uuid).then((_) => cubit.load(refresh: true));
        } else if (v == 2 && member.canDemote) {
          cubit.demote(member.uuid).then((_) => cubit.load(refresh: true));
        } else if (v == 3 && member.canRemove) {
          cubit.remove(member.uuid).then((_) => cubit.load(refresh: true));
        }
      },
      itemBuilder: (_) => [
        if (member.canPromote)
          const PopupMenuItem(value: 1, child: Text('Promote')),
        if (member.canDemote)
          const PopupMenuItem(value: 2, child: Text('Demote')),
        if (member.canRemove)
          const PopupMenuItem(
            value: 3,
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}
