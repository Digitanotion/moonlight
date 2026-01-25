import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/add_member_sheet.dart';
import '../cubit/club_members_cubit.dart';
import '../cubit/club_members_state.dart';
import 'widgets/club_member_card.dart';

class ClubMembersPage extends StatefulWidget {
  final String club;
  const ClubMembersPage({super.key, required this.club});

  @override
  State<ClubMembersPage> createState() => _ClubMembersPageState();
}

class _ClubMembersPageState extends State<ClubMembersPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<ClubMembersCubit>().load();

    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        context.read<ClubMembersCubit>().loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F2C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Members',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButton: const _FloatingInviteButton(),
      body: SafeArea(
        child: Column(children: const [_SearchBar(), _Tabs(), _MembersList()]),
      ),
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BlocBuilder<ClubMembersCubit, ClubMembersState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.members.isEmpty) {
            return const Center(
              child: Text(
                'No members found',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.members.length + (state.loadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.members.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return ClubMemberCard(member: state.members[index]);
            },
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        onChanged: (v) {
          if (v.isEmpty) {
            context.read<ClubMembersCubit>().clearSearch();
          } else {
            context.read<ClubMembersCubit>().search(v);
          }
        },
        decoration: InputDecoration(
          hintText: 'Search members',
          hintStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          filled: true,
          fillColor: const Color(0xFF121A4A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClubMembersCubit, ClubMembersState>(
      builder: (context, _) {
        final cubit = context.read<ClubMembersCubit>();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _TabItem(
                text: 'All Members',
                active: cubit.currentFilter == MembersFilter.all,
                onTap: () => cubit.setFilter(MembersFilter.all),
              ),
              const SizedBox(width: 8),
              _TabItem(
                text: 'Recently Joined',
                active: cubit.currentFilter == MembersFilter.recentlyJoined,
                onTap: () => cubit.setFilter(MembersFilter.recentlyJoined),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _TabItem({
    required this.text,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFF7A00) : const Color(0xFF121A4A),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _FloatingInviteButton extends StatelessWidget {
  const _FloatingInviteButton();

  @override
  Widget build(BuildContext context) {
    final club = context.read<ClubMembersCubit>().club;

    return FloatingActionButton(
      backgroundColor: const Color(0xFFFF7A00),
      elevation: 10,
      onPressed: () async {
        final added = await showAddMemberSheet(context, club);

        if (added == true && context.mounted) {
          context.read<ClubMembersCubit>().load(refresh: true);
        }
      },
      child: const Icon(Icons.person_add, color: Colors.white),
    );
  }
}
