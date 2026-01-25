import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/club_members_cubit.dart';
import '../cubit/club_members_state.dart';
import 'widgets/club_member_card.dart';

class ClubMembersPageUser extends StatefulWidget {
  final String club;
  const ClubMembersPageUser({super.key, required this.club});

  @override
  State<ClubMembersPageUser> createState() => _ClubMembersPageUserState();
}

class _ClubMembersPageUserState extends State<ClubMembersPageUser> {
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
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F2C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Members',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _SearchBar(),
            const _Tabs(),
            Expanded(child: _MembersList(scrollController: _scroll)),
          ],
        ),
      ),
    );
  }
}

class _MembersList extends StatelessWidget {
  final ScrollController scrollController;

  const _MembersList({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClubMembersCubit, ClubMembersState>(
      builder: (context, state) {
        if (state.loading && state.members.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
          );
        }

        if (state.members.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.white54),
                  SizedBox(height: 16),
                  Text(
                    'No members found',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Be the first to join this club!',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: state.members.length + (state.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.members.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
                ),
              );
            }
            return ClubMemberCard(member: state.members[index]);
          },
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121A4A),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
            hintText: 'Search members...',
            hintStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.search, color: Colors.white70),
            filled: true,
            fillColor: Colors.transparent,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
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
      builder: (context, state) {
        final cubit = context.read<ClubMembersCubit>();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121A4A),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TabItem(
                  text: 'All Members',
                  active: cubit.currentFilter == MembersFilter.all,
                  onTap: () => cubit.setFilter(MembersFilter.all),
                ),
                _TabItem(
                  text: 'Recently Joined',
                  active: cubit.currentFilter == MembersFilter.recentlyJoined,
                  onTap: () => cubit.setFilter(MembersFilter.recentlyJoined),
                ),
              ],
            ),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF7A00) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
