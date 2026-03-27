// lib/features/clubs/presentation/pages/widgets/add_member_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/clubs/domain/entities/user_search_result.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/widgets/top_snack.dart';

Future<bool?> showAddMemberSheet(BuildContext context, String club) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0A0F2C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return RepositoryProvider.value(
        value: sl<ClubsRepository>(),
        child: _AddMemberSheet(club),
      );
    },
  );
}

class _AddMemberSheet extends StatefulWidget {
  final String club;
  const _AddMemberSheet(this.club);

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;
  bool _loading = false;
  bool _addingMembers = false;

  List<UserSearchResult> _results = [];
  final List<UserSearchResult> _selectedUsers = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    if (value.trim().length < 2) {
      setState(() => _results = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final repo = context.read<ClubsRepository>();
      try {
        final users = await repo.searchUsers(value.trim());
        if (mounted) {
          // Filter out already selected users
          final filteredUsers = users.where((user) {
            return !_selectedUsers.any(
              (selected) => selected.uuid == user.uuid,
            );
          }).toList();
          setState(() => _results = filteredUsers);
        }
      } catch (e) {
        if (mounted) {
          TopSnack.error(context, 'Failed to search users');
        }
      }
    });
  }

  void _selectUser(UserSearchResult user) {
    setState(() {
      _selectedUsers.add(user);
      _results.remove(user);
      _controller.clear();
      _focus.requestFocus();
    });
  }

  void _removeSelectedUser(UserSearchResult user) {
    setState(() {
      _selectedUsers.remove(user);
    });
  }

  Future<void> _addMembers() async {
    if (_selectedUsers.isEmpty) return;

    setState(() => _addingMembers = true);

    final repo = context.read<ClubsRepository>();

    // Prepare bulk member data
    final members = _selectedUsers.map((user) {
      return BulkMember(
        identifier: user.slug, // Use user_slug as identifier
        role: 'member',
      );
    }).toList();

    try {
      final result = await repo.bulkAddMembers(
        club: widget.club,
        members: members,
      );

      if (!mounted) return;

      setState(() => _addingMembers = false);

      // Show results
      if (result.failed.isEmpty) {
        // All succeeded
        TopSnack.success(
          context,
          result.success.length == 1
              ? 'Added ${result.success.first.fullname} to club'
              : 'Added ${result.success.length} members to club',
        );
        Navigator.pop(context, true);
      } else if (result.success.isNotEmpty && result.failed.isNotEmpty) {
        // Partial success
        final failedNames = result.failed.map((f) => f.identifier).join(', ');
        TopSnack.warning(
          context,
          'Added ${result.success.length} members, failed to add ${result.failed.length}: $failedNames',
          duration: const Duration(seconds: 5),
        );
        // Keep sheet open and clear successful ones
        setState(() {
          _selectedUsers.removeWhere((user) {
            return result.success.any((s) => s.identifier == user.slug);
          });
        });
      } else {
        // All failed
        TopSnack.error(
          context,
          'Failed to add members: ${result.failed.first.error}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addingMembers = false);
        TopSnack.error(context, 'Failed to add members: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Add Members',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search and select users to add',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),

          /// ───── Selected Users Preview ─────
          if (_selectedUsers.isNotEmpty)
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                controller: _scrollController,
                itemCount: _selectedUsers.length,
                itemBuilder: (_, index) {
                  final user = _selectedUsers[index];
                  return _SelectedUserCard(
                    user: user,
                    onClear: () => _removeSelectedUser(user),
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          /// ───── Search Input ─────
          TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: !_addingMembers,
            style: const TextStyle(color: Colors.white),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: _selectedUsers.isEmpty
                  ? 'Search by username or email'
                  : 'Search another member...',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF121A4A),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          /// ───── Search Results ─────
          if (_results.isNotEmpty && !_addingMembers)
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final user = _results[i];
                  return _UserSuggestionTile(
                    user: user,
                    onTap: () => _selectUser(user),
                  );
                },
              ),
            ),

          const SizedBox(height: 20),

          /// ───── Add Button ─────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_addingMembers || _selectedUsers.isEmpty)
                  ? null
                  : _addMembers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _addingMembers
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Add ${_selectedUsers.isEmpty ? '' : '(${_selectedUsers.length})'} to Club',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSuggestionTile extends StatelessWidget {
  final UserSearchResult user;
  final VoidCallback onTap;

  const _UserSuggestionTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl!)
            : null,
      ),
      title: Text(
        user.fullname ?? user.email.split('@').first,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        '@${user.slug}',
        style: const TextStyle(color: Colors.white60),
      ),
    );
  }
}

class _SelectedUserCard extends StatelessWidget {
  final UserSearchResult user;
  final VoidCallback onClear;

  const _SelectedUserCard({required this.user, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121A4A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${user.fullname}\n@${user.slug}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
