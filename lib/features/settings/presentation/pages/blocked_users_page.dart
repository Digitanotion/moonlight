import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart' as di;
import 'package:moonlight/features/settings/domain/entities/blocked_user.dart';
import 'package:moonlight/features/settings/domain/repositories/blocked_users_repository.dart';
import 'package:moonlight/features/settings/presentation/cubit/blocked_users_cubit.dart';

class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          BlockedUsersCubit(di.sl<BlockedUsersRepository>())
            ..loadBlockedUsers(),
      child: Scaffold(
        backgroundColor: const Color(0xFF060522),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Blocked Users',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: _BlockedUsersContent(),
      ),
    );
  }
}

class _BlockedUsersContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BlockedUsersCubit, BlockedUsersState>(
      listener: (context, state) {
        if (state.status == BlockedUsersStatus.error && state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<BlockedUsersCubit>();

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0B2E), Color(0xFF060522)],
            ),
          ),
          child: Column(
            children: [
              // Info Banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.blueAccent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blueAccent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Blocked users cannot message you or see your content.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Loading and empty states
              if (state.status == BlockedUsersStatus.loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepOrangeAccent,
                    ),
                  ),
                )
              else if (state.blockedUsers.isEmpty)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block_rounded,
                        size: 80,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Blocked Users',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48.0),
                        child: Text(
                          state.searchQuery != null
                              ? 'No users found matching "${state.searchQuery}"'
                              : 'Users you block will appear here. You can unblock them anytime.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // if (state.searchQuery == null)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 20),
                      //     child: ElevatedButton(
                      //       onPressed: () {
                      //         // Implement search functionality
                      //       },
                      //       style: ElevatedButton.styleFrom(
                      //         backgroundColor: Colors.deepOrangeAccent,
                      //         foregroundColor: Colors.white,
                      //       ),
                      //       child: const Text('Search Users to Block'),
                      //     ),
                      //   ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    backgroundColor: Colors.deepOrangeAccent,
                    color: Colors.white,
                    onRefresh: () async => cubit.loadBlockedUsers(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.blockedUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = state.blockedUsers[index];
                        return _BlockedUserTile(
                          user: user,
                          isBlocked: user.isBlocked,
                          onToggle: (block) =>
                              cubit.toggleBlockUser(user.id, block),
                        );
                      },
                    ),
                  ),
                ),

              // Search functionality - Fixed duplicate AppBar issue
              if (state.searchQuery != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search users...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.07),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            if (value.length >= 2) {
                              cubit.searchUsers(value);
                            } else if (value.isEmpty) {
                              cubit.loadBlockedUsers();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          cubit.clearSearch();
                          cubit.loadBlockedUsers();
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Rest of your widget classes remain the same...
class _BlockedUserTile extends StatelessWidget {
  final BlockedUser user;
  final bool isBlocked;
  final Function(bool) onToggle;

  const _BlockedUserTile({
    required this.user,
    required this.isBlocked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.deepOrangeAccent.withOpacity(0.2),
          backgroundImage: user.avatarUrl != null
              ? NetworkImage(user.avatarUrl!)
              : const AssetImage('assets/default_avatar.png') as ImageProvider,
          child: user.avatarUrl == null
              ? Icon(Icons.person, color: Colors.deepOrangeAccent)
              : null,
        ),
        title: Text(
          user.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: user.username != null
            ? Text(
                '@${user.username}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              )
            : null,
        trailing: _BlockToggleSwitch(isBlocked: isBlocked, onChanged: onToggle),
      ),
    );
  }
}

class _BlockToggleSwitch extends StatelessWidget {
  final bool isBlocked;
  final Function(bool) onChanged;

  const _BlockToggleSwitch({required this.isBlocked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Switch.adaptive(
          value: isBlocked,
          onChanged: (value) {
            if (!value) {
              // Show unblock confirmation
              showDialog(
                context: context,
                builder: (context) => _UnblockConfirmationDialog(
                  userName: 'User',
                  onConfirm: () => onChanged(false),
                ),
              );
            } else {
              onChanged(true);
            }
          },
          activeColor: Colors.redAccent,
          activeTrackColor: Colors.redAccent.withOpacity(0.3),
          inactiveThumbColor: Colors.greenAccent,
          inactiveTrackColor: Colors.greenAccent.withOpacity(0.3),
        ),
        Text(
          isBlocked ? 'Blocked' : 'Unblocked',
          style: TextStyle(
            color: isBlocked ? Colors.redAccent : Colors.greenAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UnblockConfirmationDialog extends StatelessWidget {
  final String userName;
  final VoidCallback onConfirm;

  const _UnblockConfirmationDialog({
    required this.userName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.person_add_alt_1_rounded, color: Colors.greenAccent),
          const SizedBox(width: 12),
          const Text(
            'Unblock User?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This user will be able to:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _FeatureItem(
            icon: Icons.message_rounded,
            text: 'Message you',
            color: Colors.blueAccent,
          ),
          _FeatureItem(
            icon: Icons.visibility_rounded,
            text: 'See your profile and posts',
            color: Colors.purpleAccent,
          ),
          _FeatureItem(
            icon: Icons.people_rounded,
            text: 'Join your clubs and streams',
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 16),
          Text(
            'Are you sure you want to unblock?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withOpacity(0.8),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Unblock'),
        ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _FeatureItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
