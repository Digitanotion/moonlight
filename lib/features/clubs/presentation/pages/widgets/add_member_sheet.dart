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

  Timer? _debounce;
  bool _loading = false;

  List<UserSearchResult> _results = [];
  UserSearchResult? _selected;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
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
      final users = await repo.searchUsers(value.trim());
      if (mounted) {
        setState(() => _results = users);
      }
    });
  }

  Future<void> _addMember() async {
    if (_selected == null) return;

    setState(() => _loading = true);
    final repo = context.read<ClubsRepository>();

    try {
      await repo.addMember(club: widget.club, identifier: _selected!.slug);

      if (!mounted) return;

      Navigator.pop(context, true);

      TopSnack.success(context, 'Added ${_selected!.fullname} to club');
    } catch (e) {
      if (!mounted) return;
      TopSnack.error(context, 'Failed to add member');
    } finally {
      if (mounted) setState(() => _loading = false);
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
            'Add Member',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          /// ───── Search Input ─────
          TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: _selected == null,
            style: const TextStyle(color: Colors.white),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by username or email',
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

          /// ───── Selected User Preview ─────
          if (_selected != null)
            _SelectedUserCard(
              user: _selected!,
              onClear: () {
                setState(() {
                  _selected = null;
                  _controller.clear();
                  _results = [];
                  _focus.requestFocus();
                });
              },
            ),

          /// ───── Suggestions ─────
          if (_selected == null && _results.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final user = _results[i];
                return _UserSuggestionTile(
                  user: user,
                  onTap: () {
                    setState(() {
                      _selected = user;
                      _results = [];
                      _focus.unfocus();
                    });
                  },
                );
              },
            ),

          const SizedBox(height: 20),

          /// ───── Add Button ─────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _addMember,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Add to Club',
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
      title: Text(user.fullname, style: const TextStyle(color: Colors.white)),
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
