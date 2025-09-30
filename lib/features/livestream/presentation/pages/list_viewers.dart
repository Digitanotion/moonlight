import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'package:moonlight/core/theme/app_colors.dart';
import '../../domain/entities/participant.dart';
import '../bloc/participants_bloc.dart';
import '../../domain/repositories/participants_repository.dart';

class ViewersListPage extends StatefulWidget {
  const ViewersListPage({Key? key}) : super(key: key);

  @override
  State<ViewersListPage> createState() => _ViewersListPageState();
}

class _ViewersListPageState extends State<ViewersListPage> {
  late final ParticipantsBloc _bloc;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final repo = GetIt.I<ParticipantsRepository>(); // provided by DI
    _bloc = ParticipantsBloc(repo)..add(const ParticipantsStarted());
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final cur = _scroll.position.pixels;
    if (cur >= max - 200) {
      _bloc.add(const ParticipantsNextPageRequested());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Viewers List',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => _bloc.add(const ParticipantsRefreshed()),
          ),
        ],
      ),
      body: BlocConsumer<ParticipantsBloc, ParticipantsState>(
        bloc: _bloc,
        listenWhen: (p, c) => p.error != c.error && c.error != null,
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.loading && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!state.loading && state.items.isEmpty) {
            return const Center(
              child: Text(
                'No participants yet.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _bloc.add(const ParticipantsRefreshed()),
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: state.items.length + (state.paging ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final p = state.items[i];
                return _buildViewerItem(p);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewerItem(Participant p) {
    final name = p.userSlug.isNotEmpty
        ? p.userSlug
        : p.userUuid.substring(0, 6);
    final username =
        '@${p.userSlug.isNotEmpty ? p.userSlug : p.userUuid.substring(0, 6)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C40FF), Color(0xFF8B6CFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C40FF).withOpacity(0.3),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.role,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  username,
                  style: const TextStyle(
                    color: Color(0xFF8A8A9D),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Joined ${_formatJoinTime(p.joinedAt)}',
                  style: const TextStyle(
                    color: Color(0xFF5A5A6F),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          _buildActionMenu(p),
        ],
      ),
    );
  }

  Widget _buildActionMenu(Participant p) {
    final isGuest = p.role.toLowerCase() == 'guest';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_vert_rounded,
          color: Color(0xFF8A8A9D),
          size: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) => _handleMenuAction(value, p),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'guest',
            child: Row(
              children: [
                Icon(
                  isGuest ? Icons.undo_rounded : Icons.mic_rounded,
                  color: AppColors.dark,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  isGuest ? 'Return to Viewer' : 'Make Guest',
                  style: const TextStyle(color: AppColors.dark),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: const [
                Icon(Icons.remove_circle_rounded, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Text('Remove from Stream', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, Participant p) {
    switch (action) {
      case 'guest':
        final isGuest = p.role.toLowerCase() == 'guest';
        final targetRole = isGuest ? 'viewer' : 'guest';
        final display = p.userSlug.isEmpty ? p.userUuid : p.userSlug;

        _confirm(
          isGuest ? 'Return to Viewer' : 'Make Guest',
          isGuest
              ? 'Return $display to the audience?'
              : 'Invite $display as a guest?',
          onConfirm: () =>
              _bloc.add(ParticipantActionRole(p.userUuid, targetRole)),
        );
        break;

      case 'remove':
        _confirm(
          'Remove Viewer',
          'Remove ${p.userSlug.isEmpty ? p.userUuid : p.userSlug} from the stream?',
          onConfirm: () => _bloc.add(ParticipantActionRemove(p.userUuid)),
        );
        break;
    }
  }

  void _confirm(
    String title,
    String message, {
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF8A8A9D)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8A8A9D)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text(
              'Confirm',
              style: TextStyle(color: Color(0xFF6C40FF)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatJoinTime(DateTime joinTime) {
    final difference = DateTime.now().difference(joinTime);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}
