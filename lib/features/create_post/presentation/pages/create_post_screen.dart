// lib/features/create_post/presentation/pages/create_post_screen.dart
//
// Composer redesigned around a Twitter/X-style "compose" flow — avatar +
// auto-focused text right up top, no boxed form fields — but built with
// Moonlight's own palette and its own shortcuts instead of a copy: a row
// of one-tap action cards (camera / gallery / video / hashtag / audience)
// stands in for Twitter's attachment strip, and the bottom toolbar's
// character ring blends into the Post button's own glow rather than
// sitting in a separate grey circle.
//
// Same submission contract as before (media required, 200-char caption,
// CreatePostCubit.submit) — only the presentation changed.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/post_view/presentation/widgets/user_helper.dart';
import '../../domain/entities/create_post_payload.dart';
import '../cubit/create_post_cubit.dart';

const int _kMaxCaptionLength = 200;

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  final _hashtag = TextEditingController();
  final _hashtagFocus = FocusNode();
  final _tags = <String>[];
  PostVisibility _visibility = PostVisibility.everyone;

  XFile? _media;
  bool _isVideo = false;
  bool _picking = false;
  bool _showHashtagPanel = false;

  @override
  void initState() {
    super.initState();
    _caption.addListener(_onCaptionChanged);
  }

  void _onCaptionChanged() => setState(() {});

  @override
  void dispose() {
    _caption.removeListener(_onCaptionChanged);
    _caption.dispose();
    _hashtag.dispose();
    _hashtagFocus.dispose();
    super.dispose();
  }

  int get _length => _caption.text.length;
  bool get _overLimit => _length > _kMaxCaptionLength;
  bool get _canSubmit => _media != null && !_overLimit;

  Future<void> _pickDirect(_PickKind kind, _PickSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      XFile? x;
      if (kind == _PickKind.image) {
        x = await picker.pickImage(
          source: source == _PickSource.gallery
              ? ImageSource.gallery
              : ImageSource.camera,
          imageQuality: 92,
        );
      } else {
        x = await picker.pickVideo(
          source: source == _PickSource.gallery
              ? ImageSource.gallery
              : ImageSource.camera,
          maxDuration: const Duration(minutes: 5),
        );
      }
      if (x != null && mounted) {
        setState(() {
          _media = x;
          _isVideo = kind == _PickKind.video;
        });
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickViaSheet() async {
    final choice = await showModalBottomSheet<_PickChoice>(
      context: context,
      backgroundColor: const Color(0xFF10132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PickSheet(),
    );
    if (choice == null) return;
    await _pickDirect(choice.kind, choice.source);
  }

  void _addTagFromInput() {
    final t = _hashtag.text.trim();
    if (t.isEmpty) return;
    if (_tags.length >= 10) return;
    final clean = t.startsWith('#') ? t.substring(1) : t;
    if (clean.isEmpty || _tags.contains(clean)) return;
    setState(() {
      _tags.add(clean);
      _hashtag.clear();
    });
  }

  void _removeTag(String t) => setState(() => _tags.remove(t));

  Future<void> _openVisibilitySheet() async {
    final result = await showModalBottomSheet<PostVisibility>(
      context: context,
      backgroundColor: const Color(0xFF10132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VisibilitySheet(current: _visibility),
    );
    if (result != null) setState(() => _visibility = result);
  }

  Future<void> _submit() async {
    if (_media == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a photo or video to post.')),
      );
      return;
    }
    if (_overLimit) return;

    final payload = CreatePostPayload(
      caption: _caption.text.trim(),
      tags: _tags,
      visibility: _visibility,
      mediaPath: _media!.path,
    );

    await context.read<CreatePostCubit>().submit(payload);
    final st = context.read<CreatePostCubit>().state;
    if (st.created != null && mounted) {
      Navigator.popUntil(context, (r) => r.isFirst);
      Navigator.pushReplacementNamed(context, RouteNames.postsPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgTop, AppColors.bgBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: BlocConsumer<CreatePostCubit, CreatePostState>(
            listener: (context, state) {
              if (state.error != null && state.error!.isNotEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.error!)));
              }
            },
            builder: (context, state) {
              return SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      submitting: state.submitting,
                      canSubmit: _canSubmit,
                      onClose: () => Navigator.maybePop(context),
                      onSubmit: _submit,
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        children: [
                          _ComposerRow(
                            controller: _caption,
                            avatarUrl: UserHelper.getCurrentUserAvatar(context),
                          ),
                          const SizedBox(height: 10),
                          _VisibilityPill(
                            visibility: _visibility,
                            onTap: _openVisibilitySheet,
                          ),
                          const SizedBox(height: 18),
                          _MediaArea(
                            media: _media,
                            isVideo: _isVideo,
                            picking: _picking,
                            onAdd: _pickViaSheet,
                            onChange: _pickViaSheet,
                            onRemove: () => setState(() {
                              _media = null;
                              _isVideo = false;
                            }),
                          ),
                          const SizedBox(height: 20),
                          _QuickActionsRow(
                            tagCount: _tags.length,
                            visibility: _visibility,
                            onCamera: () => _pickDirect(
                              _PickKind.image,
                              _PickSource.camera,
                            ),
                            onGallery: () => _pickDirect(
                              _PickKind.image,
                              _PickSource.gallery,
                            ),
                            onVideo: () => _pickDirect(
                              _PickKind.video,
                              _PickSource.gallery,
                            ),
                            onHashtag: () {
                              setState(
                                () => _showHashtagPanel = !_showHashtagPanel,
                              );
                              if (_showHashtagPanel) {
                                Future.delayed(
                                  const Duration(milliseconds: 80),
                                  () => _hashtagFocus.requestFocus(),
                                );
                              }
                            },
                            onAudience: _openVisibilitySheet,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: _showHashtagPanel
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 18),
                                    child: _HashtagPanel(
                                      controller: _hashtag,
                                      focusNode: _hashtagFocus,
                                      tags: _tags,
                                      onAdd: _addTagFromInput,
                                      onRemove: _removeTag,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    _BottomToolbar(
                      length: _length,
                      maxLength: _kMaxCaptionLength,
                      hashtagActive: _showHashtagPanel,
                      visibility: _visibility,
                      onGallery: _pickViaSheet,
                      onHashtag: () {
                        setState(() => _showHashtagPanel = !_showHashtagPanel);
                      },
                      onAudience: _openVisibilitySheet,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Top bar: close + Post pill ─────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.submitting,
    required this.canSubmit,
    required this.onClose,
    required this.onSubmit,
  });

  final bool submitting;
  final bool canSubmit;
  final VoidCallback onClose;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final enabled = canSubmit && !submitting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            iconSize: 26,
          ),
          const Spacer(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: enabled ? 1 : 0.45,
            child: GestureDetector(
              onTap: enabled ? onSubmit : null,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.secondary, AppColors.primary2],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Post',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar + auto-focused text field ───────────────────────────────────────
class _ComposerRow extends StatelessWidget {
  const _ComposerRow({required this.controller, required this.avatarUrl});

  final TextEditingController controller;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(url: avatarUrl),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: AppColors.secondary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
            decoration: const InputDecoration(
              hintText: "What's on your mind?",
              hintStyle: TextStyle(
                color: Colors.white38,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final valid = url.isNotEmpty && Uri.tryParse(url)?.hasScheme == true;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.secondary, AppColors.primary2],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.25),
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: valid
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
    color: AppColors.dark,
    child: const Icon(Icons.person_rounded, color: Colors.white70, size: 22),
  );
}

// ── Compact "who can see this" pill under the composer ──────────────────────
class _VisibilityPill extends StatelessWidget {
  const _VisibilityPill({required this.visibility, required this.onTap});

  final PostVisibility visibility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _visibilityIcon(visibility),
              size: 14,
              color: AppColors.secondary,
            ),
            const SizedBox(width: 6),
            Text(
              _visibilityLabel(visibility),
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.secondary.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _visibilityIcon(PostVisibility v) {
  switch (v) {
    case PostVisibility.everyone:
      return Icons.public_rounded;
    case PostVisibility.followers:
      return Icons.group_rounded;
    case PostVisibility.onlyMe:
      return Icons.lock_rounded;
  }
}

String _visibilityLabel(PostVisibility v) {
  switch (v) {
    case PostVisibility.everyone:
      return 'Everyone';
    case PostVisibility.followers:
      return 'Followers';
    case PostVisibility.onlyMe:
      return 'Only me';
  }
}

// ── Media: slim add-prompt when empty, full preview once picked ────────────
class _MediaArea extends StatelessWidget {
  const _MediaArea({
    required this.media,
    required this.isVideo,
    required this.picking,
    required this.onAdd,
    required this.onChange,
    required this.onRemove,
  });

  final XFile? media;
  final bool isVideo;
  final bool picking;
  final VoidCallback onAdd;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (media == null) {
      return GestureDetector(
        onTap: picking ? null : onAdd,
        child: DottedBorderBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Column(
              children: [
                if (picking)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.secondary,
                    ),
                  )
                else ...[
                  const Icon(
                    Icons.add_photo_alternate_rounded,
                    color: AppColors.secondary,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add a photo or video',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onChange,
              child: isVideo
                  ? Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 60,
                          color: Colors.white70,
                        ),
                      ),
                    )
                  : Image.file(File(media!.path), fit: BoxFit.cover),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed-border prompt card — visually distinct from any solid input so
/// the "add media" affordance reads as an attach action, not a text field.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.secondary.withValues(alpha: 0.45),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      const dashWidth = 6.0;
      const gapWidth = 5.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Horizontal quick-action cards ───────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.tagCount,
    required this.visibility,
    required this.onCamera,
    required this.onGallery,
    required this.onVideo,
    required this.onHashtag,
    required this.onAudience,
  });

  final int tagCount;
  final PostVisibility visibility;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onVideo;
  final VoidCallback onHashtag;
  final VoidCallback onAudience;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ActionCard(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            onTap: onCamera,
          ),
          _ActionCard(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            onTap: onGallery,
          ),
          _ActionCard(
            icon: Icons.videocam_rounded,
            label: 'Video',
            onTap: onVideo,
          ),
          _ActionCard(
            icon: Icons.tag_rounded,
            label: tagCount == 0
                ? 'Hashtag'
                : '$tagCount tag${tagCount == 1 ? '' : 's'}',
            onTap: onHashtag,
          ),
          _ActionCard(
            icon: _visibilityIcon(visibility),
            label: _visibilityLabel(visibility),
            onTap: onAudience,
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 82,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.secondary, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hashtag input + chips (toggled from the row/toolbar) ───────────────────
class _HashtagPanel extends StatelessWidget {
  const _HashtagPanel({
    required this.controller,
    required this.focusNode,
    required this.tags,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> tags;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add a hashtag',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (t) => Chip(
                    backgroundColor: AppColors.secondary.withValues(
                      alpha: 0.14,
                    ),
                    side: BorderSide(
                      color: AppColors.secondary.withValues(alpha: 0.35),
                    ),
                    label: Text(
                      '#$t',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    deleteIcon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    onDeleted: () => onRemove(t),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ── Bottom docked toolbar: icons + live character ring ─────────────────────
class _BottomToolbar extends StatelessWidget {
  const _BottomToolbar({
    required this.length,
    required this.maxLength,
    required this.hashtagActive,
    required this.visibility,
    required this.onGallery,
    required this.onHashtag,
    required this.onAudience,
  });

  final int length;
  final int maxLength;
  final bool hashtagActive;
  final PostVisibility visibility;
  final VoidCallback onGallery;
  final VoidCallback onHashtag;
  final VoidCallback onAudience;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      child: Row(
        children: [
          _ToolIcon(icon: Icons.image_rounded, onTap: onGallery),
          _ToolIcon(
            icon: Icons.tag_rounded,
            active: hashtagActive,
            onTap: onHashtag,
          ),
          _ToolIcon(icon: _visibilityIcon(visibility), onTap: onAudience),
          const Spacer(),
          _CharRing(length: length, maxLength: maxLength),
        ],
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: active
            ? AppColors.secondary
            : AppColors.secondary.withValues(alpha: 0.85),
        size: 22,
      ),
    );
  }
}

class _CharRing extends StatelessWidget {
  const _CharRing({required this.length, required this.maxLength});
  final int length;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    if (length == 0) return const SizedBox(width: 28, height: 28);

    final remaining = maxLength - length;
    final ratio = (length / maxLength).clamp(0.0, 1.0);
    final danger = remaining <= 20;
    final over = remaining < 0;
    final ringColor = over
        ? AppColors.textRed
        : danger
        ? Colors.amber
        : AppColors.secondary;

    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              value: ratio,
              strokeWidth: 2.6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(ringColor),
            ),
          ),
          if (danger)
            Text(
              '$remaining',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: ringColor,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Visibility picker sheet ─────────────────────────────────────────────────
class _VisibilitySheet extends StatelessWidget {
  const _VisibilitySheet({required this.current});
  final PostVisibility current;

  @override
  Widget build(BuildContext context) {
    Widget option(PostVisibility v, String desc) {
      final selected = v == current;
      return ListTile(
        leading: Icon(
          _visibilityIcon(v),
          color: selected ? AppColors.secondary : Colors.white70,
        ),
        title: Text(
          _visibilityLabel(v),
          style: TextStyle(
            color: selected ? AppColors.secondary : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          desc,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: AppColors.secondary)
            : null,
        onTap: () => Navigator.pop(context, v),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Who can see this post?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            option(PostVisibility.everyone, 'Anyone on Moonlight'),
            option(PostVisibility.followers, 'People who follow you'),
            option(PostVisibility.onlyMe, 'Only visible to you'),
          ],
        ),
      ),
    );
  }
}

// ── Media pick sheet (used when changing an already-picked media) ──────────
enum _PickKind { image, video }

enum _PickSource { gallery, camera }

class _PickChoice {
  final _PickKind kind;
  final _PickSource source;
  _PickChoice(this.kind, this.source);
}

class _PickSheet extends StatelessWidget {
  const _PickSheet();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, _PickKind k, _PickSource s) {
      return ListTile(
        leading: Icon(icon, color: AppColors.secondary),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: () => Navigator.pop(context, _PickChoice(k, s)),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          item(
            Icons.photo_library_rounded,
            'Photo from gallery',
            _PickKind.image,
            _PickSource.gallery,
          ),
          item(
            Icons.photo_camera_rounded,
            'Photo from camera',
            _PickKind.image,
            _PickSource.camera,
          ),
          const Divider(color: Colors.white12, height: 1),
          item(
            Icons.video_library_rounded,
            'Video from gallery',
            _PickKind.video,
            _PickSource.gallery,
          ),
          item(
            Icons.videocam_rounded,
            'Video from camera',
            _PickKind.video,
            _PickSource.camera,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
