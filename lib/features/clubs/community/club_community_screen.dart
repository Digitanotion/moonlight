// lib/features/clubs/community/club_community_screen.dart
//
// The club's community: members share what's on their mind (text, photos,
// videos, voice notes), like / dislike, and talk in comments with replies.

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/features/chat/presentation/widgets/chat_special_lines.dart';
import 'package:moonlight/features/chat/presentation/widgets/video_player_dialog.dart';
import 'package:moonlight/features/clubs/community/club_community_api.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

const _bg = Color(0xFF0E0B1F);
const _card = Color(0xFF1A1533);
const _accent = Color(0xFF8B5CF6);

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${t.day}/${t.month}/${t.year}';
}

class _Avatar extends StatelessWidget {
  final CommunityAuthor author;
  final double size;
  const _Avatar(this.author, {this.size = 40});

  @override
  Widget build(BuildContext context) {
    final url = author.avatarUrl ?? '';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _accent.withValues(alpha: 0.35),
      backgroundImage: url.startsWith('http')
          ? CachedNetworkImageProvider(url)
          : null,
      child: url.startsWith('http')
          ? null
          : Text(
              author.name.isEmpty ? '?' : author.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class ClubCommunityScreen extends StatefulWidget {
  final String clubUuid;
  final String clubName;
  const ClubCommunityScreen({
    super.key,
    required this.clubUuid,
    required this.clubName,
  });

  @override
  State<ClubCommunityScreen> createState() => _ClubCommunityScreenState();
}

class _ClubCommunityScreenState extends State<ClubCommunityScreen> {
  late final _api = ClubCommunityApi(widget.clubUuid);
  final _scroll = ScrollController();
  final List<CommunityPost> _posts = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && !_hasMore)) return;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      final (list, more) = await _api.posts(page: reset ? 1 : _page);
      if (!mounted) return;
      setState(() {
        if (reset) _posts.clear();
        _posts.addAll(list);
        _page = (reset ? 1 : _page) + 1;
        _hasMore = more;
      });
    } catch (e) {
      if (mounted) setState(() => _error = communityError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _compose() async {
    final post = await showModalBottomSheet<CommunityPost>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposerSheet(api: _api),
    );
    if (post != null && mounted) {
      setState(() => _posts.insert(0, post));
      TopSnack.success(context, 'Posted to ${widget.clubName}');
    }
  }

  Future<void> _react(int i, String value) async {
    final before = _posts[i];
    final next = before.reactions.tap(value);
    setState(() => _posts[i] = before.copyWith(reactions: next));
    try {
      await _api.react(before.uuid, next.mine);
    } catch (e) {
      if (mounted) setState(() => _posts[i] = before);
    }
  }

  Future<void> _delete(int i) async {
    final post = _posts[i];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          'Delete post?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF6B81)),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deletePost(post.uuid);
      if (mounted)
        setState(() => _posts.removeWhere((p) => p.uuid == post.uuid));
    } catch (e) {
      if (mounted) TopSnack.error(context, communityError(e));
    }
  }

  Future<void> _openComments(int i) async {
    final uuid = _posts[i].uuid;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        api: _api,
        post: _posts[i],
        // Keep the post's comment count in step while the sheet is open.
        onCount: (n) {
          final j = _posts.indexWhere((p) => p.uuid == uuid);
          if (mounted && j >= 0) {
            setState(() => _posts[j] = _posts[j].copyWith(comments: n));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Community',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              widget.clubName,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
          itemCount: _posts.length + 2,
          itemBuilder: (_, i) {
            if (i == 0) return _ComposerPrompt(onTap: _compose);
            if (i == _posts.length + 1) {
              if (_error != null && _posts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60),
                  ),
                );
              }
              if (_loading) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (_posts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'No posts yet. Be the first to share what\'s on your mind!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            final idx = i - 1;
            final p = _posts[idx];
            return _PostCard(
              post: p,
              onLike: () => _react(idx, 'like'),
              onDislike: () => _react(idx, 'dislike'),
              onComments: () => _openComments(idx),
              onDelete: p.canDelete ? () => _delete(idx) : null,
            );
          },
        ),
      ),
    );
  }
}

class _ComposerPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _ComposerPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _accent.withValues(alpha: 0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: _accent),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'What\'s on your mind?',
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
            ),
            Icon(Icons.photo_library_outlined, color: Colors.white54, size: 20),
            SizedBox(width: 12),
            Icon(Icons.mic_none_rounded, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onComments;
  final VoidCallback? onDelete;
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onDislike,
    required this.onComments,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = post.reactions;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 6),
            child: Row(
              children: [
                _Avatar(post.author),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _ago(post.createdAt),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white54,
                    ),
                  ),
              ],
            ),
          ),
          if ((post.body ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                post.body!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ),
          for (final m in post.media) _MediaView(m),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
            child: Row(
              children: [
                _ActionChip(
                  icon: r.mine == 'like'
                      ? Icons.thumb_up_alt_rounded
                      : Icons.thumb_up_alt_outlined,
                  label: '${r.likes}',
                  active: r.mine == 'like',
                  onTap: onLike,
                ),
                _ActionChip(
                  icon: r.mine == 'dislike'
                      ? Icons.thumb_down_alt_rounded
                      : Icons.thumb_down_alt_outlined,
                  label: '${r.dislikes}',
                  active: r.mine == 'dislike',
                  onTap: onDislike,
                ),
                _ActionChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: post.comments == 0 ? 'Comment' : '${post.comments}',
                  onTap: onComments,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _accent : Colors.white70;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaView extends StatelessWidget {
  final CommunityMedia m;
  const _MediaView(this.m);

  @override
  Widget build(BuildContext context) {
    if (m.type == 'audio') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: VoiceNotePlayer(url: m.url, durationSeconds: m.duration),
        ),
      );
    }
    if (m.type == 'video') {
      return GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => VideoPlayerDialog(videoUrl: m.url),
        ),
        child: Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.black,
          alignment: Alignment.center,
          child: const Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 56,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (c) => GestureDetector(
          onTap: () => Navigator.pop(c),
          child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: m.url, fit: BoxFit.contain),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CachedNetworkImage(
          imageUrl: m.url,
          fit: BoxFit.cover,
          width: double.infinity,
          memCacheWidth: 1080,
          placeholder: (_, _) => Container(height: 220, color: Colors.black26),
          errorWidget: (_, _, _) => Container(
            height: 120,
            color: Colors.black26,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.white38,
            ),
          ),
        ),
      ),
    );
  }
}

// ── composer ─────────────────────────────────────────────────────────────

class _ComposerSheet extends StatefulWidget {
  final ClubCommunityApi api;
  const _ComposerSheet({required this.api});

  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final _text = TextEditingController();
  final List<File> _files = [];
  final _recorder = AudioRecorder();
  bool _recording = false;
  DateTime? _recStart;
  Timer? _ticker;
  File? _voice;
  int _voiceSeconds = 0;
  bool _posting = false;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final picked = await ImagePicker().pickMultipleMedia(limit: 4);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _voice = null;
      _files
        ..clear()
        ..addAll(picked.take(4).map((x) => File(x.path)));
    });
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      _ticker?.cancel();
      final path = await _recorder.stop();
      final secs = DateTime.now().difference(_recStart!).inSeconds;
      setState(() {
        _recording = false;
        if (path != null && secs >= 1) {
          _voice = File(path);
          _voiceSeconds = secs;
          _files.clear();
        }
      });
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) TopSnack.error(context, 'Allow the microphone to record.');
      return;
    }
    final dir = await getTemporaryDirectory();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path:
          '${dir.path}/club_voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
      if (DateTime.now().difference(_recStart!).inSeconds >= 300)
        _toggleRecord();
    });
    setState(() {
      _recording = true;
      _recStart = DateTime.now();
    });
  }

  Future<void> _post() async {
    if (_posting || _recording) return;
    if (_text.text.trim().isEmpty && _files.isEmpty && _voice == null) {
      TopSnack.info(
        context,
        'Write something or add a photo, video or voice note.',
      );
      return;
    }
    setState(() => _posting = true);
    try {
      final post = await widget.api.create(
        body: _text.text,
        files: _voice != null ? [_voice!] : _files,
        voiceSeconds: _voice != null ? _voiceSeconds : null,
      );
      if (mounted) Navigator.pop(context, post);
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      TopSnack.error(context, communityError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final recSecs = _recStart == null
        ? 0
        : DateTime.now().difference(_recStart!).inSeconds;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Create post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    onPressed: _posting ? null : _post,
                    child: Text(_posting ? 'Posting…' : 'Post'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                maxLines: 6,
                minLines: 3,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'What\'s on your mind?',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
              ),
              if (_files.isNotEmpty)
                SizedBox(
                  height: 72,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in _files)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child:
                                f.path.toLowerCase().endsWith('.mp4') ||
                                    f.path.toLowerCase().endsWith('.mov')
                                ? Container(
                                    width: 72,
                                    color: Colors.black,
                                    child: const Icon(
                                      Icons.videocam_rounded,
                                      color: Colors.white,
                                    ),
                                  )
                                : Image.file(
                                    f,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (_voice != null)
                Row(
                  children: [
                    Expanded(
                      child: VoiceNotePlayer(
                        url: '',
                        localFile: _voice,
                        durationSeconds: _voiceSeconds,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _voice = null),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _recording ? null : _pickMedia,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Photo / video'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _toggleRecord,
                    style: TextButton.styleFrom(
                      foregroundColor: _recording
                          ? const Color(0xFFFF3B30)
                          : null,
                    ),
                    icon: Icon(
                      _recording
                          ? Icons.stop_circle_rounded
                          : Icons.mic_rounded,
                    ),
                    label: Text(
                      _recording
                          ? 'Stop ${recSecs ~/ 60}:${(recSecs % 60).toString().padLeft(2, '0')}'
                          : 'Voice',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── comments ─────────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final ClubCommunityApi api;
  final CommunityPost post;
  final ValueChanged<int> onCount;
  const _CommentsSheet({
    required this.api,
    required this.post,
    required this.onCount,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  List<CommunityComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  CommunityComment? _replyTo;

  int get _count => _comments.fold(0, (n, c) => n + 1 + c.replies.length);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await widget.api.comments(widget.post.uuid);
      if (mounted) setState(() => _comments = list);
      widget.onCount(_count);
    } catch (e) {
      if (mounted) TopSnack.error(context, communityError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.api.addComment(
        widget.post.uuid,
        text,
        parent: _replyTo?.uuid,
      );
      _input.clear();
      setState(() => _replyTo = null);
      await _load();
    } catch (e) {
      if (mounted) TopSnack.error(context, communityError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _react(CommunityComment c, String value) async {
    final next = c.reactions.tap(value);
    CommunityComment swap(CommunityComment x) => x.uuid == c.uuid
        ? x.withReactions(next)
        : CommunityComment(
            uuid: x.uuid,
            body: x.body,
            author: x.author,
            reactions: x.reactions,
            canDelete: x.canDelete,
            createdAt: x.createdAt,
            replies: x.replies.map(swap).toList(),
          );
    setState(() => _comments = _comments.map(swap).toList());
    try {
      await widget.api.reactComment(c.uuid, next.mine);
    } catch (_) {
      _load();
    }
  }

  Future<void> _delete(CommunityComment c) async {
    try {
      await widget.api.deleteComment(c.uuid);
      await _load();
    } catch (e) {
      if (mounted) TopSnack.error(context, communityError(e));
    }
  }

  Widget _comment(CommunityComment c, {bool reply = false}) {
    final r = c.reactions;
    return Padding(
      padding: EdgeInsets.fromLTRB(reply ? 48 : 0, 8, 0, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(c.author, size: reply ? 28 : 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.author.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.body,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Wrap (not Row): on narrow phones the actions used to
                // overflow off the right edge.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _ago(c.createdAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _react(c, 'like'),
                      child: Text(
                        '👍 ${r.likes}',
                        style: TextStyle(
                          color: r.mine == 'like' ? _accent : Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _react(c, 'dislike'),
                      child: Text(
                        '👎 ${r.dislikes}',
                        style: TextStyle(
                          color: r.mine == 'dislike' ? _accent : Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _replyTo = c);
                        _focus.requestFocus();
                      },
                      child: const Text(
                        'Reply',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                    if (c.canDelete)
                      TextButton(
                        onPressed: () => _delete(c),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Color(0xFFFF6B81),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                for (final rep in c.replies) _comment(rep, reply: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Comments',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                  ? const Center(
                      child: Text(
                        'No comments yet — start the conversation.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : TextButtonTheme(
                      data: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        children: [for (final c in _comments) _comment(c)],
                      ),
                    ),
            ),
            if (_replyTo != null)
              Container(
                color: Colors.white.withValues(alpha: 0.05),
                padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${_replyTo!.author.name}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _replyTo = null),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _replyTo == null
                              ? 'Write a comment…'
                              : 'Write a reply…',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded, color: _accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
