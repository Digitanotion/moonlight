import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import '../../domain/entities/create_post_payload.dart';
import '../cubit/create_post_cubit.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  final _hashtag = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _tags = <String>[];
  PostVisibility _visibility = PostVisibility.everyone;

  XFile? _media;
  bool _isVideo = false;
  bool _picking = false;

  @override
  void dispose() {
    _caption.dispose();
    _hashtag.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    if (_picking) return;
    setState(() => _picking = true);

    try {
      // Bottom sheet to choose image/video + source
      final choice = await showModalBottomSheet<_PickChoice>(
        context: context,
        backgroundColor: const Color(0xFF0F1432),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        builder: (_) => _PickSheet(),
      );

      if (choice == null) return;

      final picker = ImagePicker();
      XFile? x;

      if (choice.kind == _PickKind.image) {
        x = await picker.pickImage(
          source: choice.source == _PickSource.gallery
              ? ImageSource.gallery
              : ImageSource.camera,
          imageQuality: 92,
        );
        if (x != null)
          setState(() {
            _media = x;
            _isVideo = false;
          });
      } else {
        x = await picker.pickVideo(
          source: choice.source == _PickSource.gallery
              ? ImageSource.gallery
              : ImageSource.camera,
          maxDuration: const Duration(minutes: 5),
        );
        if (x != null)
          setState(() {
            _media = x;
            _isVideo = true;
          });
      }
    } finally {
      setState(() => _picking = false);
    }
  }

  void _addTagFromInput() {
    final t = _hashtag.text.trim();
    if (t.isEmpty) return;
    if (_tags.length >= 10) return;
    if (_tags.contains(t)) return;
    setState(() {
      _tags.add(t.startsWith('#') ? t.substring(1) : t);
      _hashtag.clear();
    });
  }

  void _removeTag(String t) => setState(() => _tags.remove(t));

  Future<void> _submit() async {
    if (_media == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo or video.')),
      );
      return;
    }
    if (_caption.text.trim().length > 200) return; // form guard

    final payload = CreatePostPayload(
      caption: _caption.text.trim(),
      tags: _tags,
      visibility: _visibility,
      mediaPath: _media!.path,
    );

    await context.read<CreatePostCubit>().submit(payload);
    final st = context.read<CreatePostCubit>().state;
    if (st.created != null && mounted) {
      // Jump to Feed and refresh
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
            colors: [Color(0xFF0B1E5F), Color(0xFF0A0B12)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.maybePop(context),
            ),
            centerTitle: true,
            title: const Text(
              'Create a Post',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: BlocConsumer<CreatePostCubit, CreatePostState>(
            listener: (context, state) {
              if (state.error != null && state.error!.isNotEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.error!)));
              }
            },
            builder: (context, state) {
              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Media picker card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickMedia,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: _media == null
                                      ? _EmptyMedia()
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              // For simplicity show the first frame for image;
                                              // for video, just a dim cover with a play badge.
                                              if (!_isVideo)
                                                Image.file(
                                                  File(_media!.path),
                                                  fit: BoxFit.cover,
                                                )
                                              else
                                                Container(
                                                  color: Colors.black26,
                                                ),
                                              if (_isVideo)
                                                const Center(
                                                  child: Icon(
                                                    Icons.play_circle_fill,
                                                    size: 64,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),

                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: AppColors.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Caption box
                    TextFormField(
                      controller: _caption,
                      maxLines: 5,
                      maxLength: 200,
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                      decoration: _inputDecoration(
                        'Say somethings about your post...',
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text(
                      'Who can see the post?',
                      style: AppTextStyles.body.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),

                    _VisibilityDropdown(
                      value: _visibility,
                      onChanged: (v) => setState(() => _visibility = v),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'Add hashtags',
                      style: AppTextStyles.body.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hashtag,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              'Type hashtag and press enter',
                            ),
                            onSubmitted: (_) => _addTagFromInput(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _addTagFromInput,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags
                          .map(
                            (t) => Chip(
                              backgroundColor: Colors.white.withOpacity(0.08),
                              label: Text(
                                '#$t',
                                style: const TextStyle(
                                  color: AppColors.bluePrimaryDark,
                                ),
                              ),
                              onDeleted: () => _removeTag(t),
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: state.submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: state.submitting
                              ? Colors.white24
                              : AppColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: state.submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Post to Feed',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                      ),
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white60),
      counterStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      contentPadding: const EdgeInsets.all(16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.secondary.withOpacity(0.9),
          width: 1.4,
        ),
      ),
    );
  }
}

class _VisibilityDropdown extends StatelessWidget {
  const _VisibilityDropdown({required this.value, required this.onChanged});
  final PostVisibility value;
  final ValueChanged<PostVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<PostVisibility>(
        value: value,
        underline: const SizedBox.shrink(),
        isExpanded: true,
        dropdownColor: const Color(0xFF0F1432),
        iconEnabledColor: Colors.white,
        style: const TextStyle(color: Colors.white),
        items: const [
          DropdownMenuItem(
            value: PostVisibility.everyone,
            child: Text('Everyone'),
          ),
          DropdownMenuItem(
            value: PostVisibility.followers,
            child: Text('Followers only'),
          ),
          DropdownMenuItem(
            value: PostVisibility.onlyMe,
            child: Text('Only me'),
          ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _EmptyMedia extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.cloud_upload_outlined, color: Colors.white70, size: 36),
          SizedBox(height: 8),
          Text(
            'Upload a photo or video',
            style: TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 4),
          Text(
            'Tap to select from gallery',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

enum _PickKind { image, video }

enum _PickSource { gallery, camera }

class _PickChoice {
  final _PickKind kind;
  final _PickSource source;
  _PickChoice(this.kind, this.source);
}

class _PickSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, _PickKind k, _PickSource s) {
      return ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        onTap: () => Navigator.pop(context, _PickChoice(k, s)),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(
            Icons.photo_library,
            'Photo from gallery',
            _PickKind.image,
            _PickSource.gallery,
          ),
          item(
            Icons.photo_camera,
            'Photo from camera',
            _PickKind.image,
            _PickSource.camera,
          ),
          const Divider(color: Colors.white24, height: 1),
          item(
            Icons.video_library,
            'Video from gallery',
            _PickKind.video,
            _PickSource.gallery,
          ),
          item(
            Icons.videocam,
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
