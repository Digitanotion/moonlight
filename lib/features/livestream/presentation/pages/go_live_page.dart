import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/features/livestream/presentation/cubits/go_live_cubit.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/livestream.dart';
import '../widgets/gl_toggle_tile.dart';
import '../widgets/gl_section_card.dart';
import '../widgets/live_snack.dart';

class GoLivePage extends StatefulWidget {
  const GoLivePage({super.key});

  @override
  State<GoLivePage> createState() => _GoLivePageState();
}

class _GoLivePageState extends State<GoLivePage> {
  final _titleCtrl = TextEditingController();
  File? _cover;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GoLiveCubit, GoLiveState>(
      listenWhen: (p, c) => p.status != c.status || p.message != c.message,
      listener: (context, state) async {
        if (state.status == GoLiveStatus.error && state.message != null) {
          showLiveSnack(context, state.message!);
        }
        if (state.status == GoLiveStatus.success && state.created != null) {
          // Navigate to your Host screen that joins Agora as publisher with returned rtc_token
          Navigator.of(context).pushNamed(
            '/live/host',
            arguments:
                state.created, // Livestream entity with uuid, channel, token
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<GoLiveCubit>();
        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Go Live',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            centerTitle: true,
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  // Cover
                  GLSectionCard(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final x = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                          );
                          if (x != null) setState(() => _cover = File(x.path));
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFF0E1533),
                            border: Border.all(
                              color: Colors.white10,
                              width: 1,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: _cover == null
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.camera_alt_outlined,
                                        color: Colors.white70,
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Add Cover Photo',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(_cover!, fit: BoxFit.cover),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  _InputBox(
                    label: 'Stream Title',
                    hint: 'Give your stream a title',
                    controller: _titleCtrl,
                    onChanged: cubit.titleChanged,
                  ),

                  const SizedBox(height: 12),

                  // Category (mock for now, replace with real list)
                  _DropdownBox(
                    label: 'Category',
                    value: state.category,
                    hint: 'Select category',
                    items: const [
                      'Education',
                      'Gaming',
                      'Lifestyle',
                      'Health',
                      'Music',
                    ],
                    onChanged: cubit.categoryChanged,
                  ),

                  const SizedBox(height: 16),

                  // Camera preview placeholder card (UI match)
                  GLSectionCard(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1533),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.videocam_off_rounded,
                            color: Colors.white54,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Stream Settings toggles (order & copy matches screenshot)
                  const _SectionTitle('Stream Settings'),
                  GLToggleTile(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Premium Stream',
                    subtitle: 'Viewers pay coins to join',
                    value:
                        state.record, // NOTE: keep UI, but premium flow later.
                    onChanged: cubit.recordToggled,
                  ),
                  GLToggleTile(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Allow Guest Box',
                    subtitle: 'Viewers can request to join',
                    value: state.allowGuests,
                    onChanged: cubit.allowGuestBoxToggled,
                  ),
                  GLToggleTile(
                    icon: Icons.chat_bubble_rounded,
                    title: 'Enable Comments',
                    subtitle: 'Allow viewers to chat',
                    value: state.enableComments,
                    onChanged: cubit.enableCommentsToggled,
                  ),
                  GLToggleTile(
                    icon: Icons.remove_red_eye_rounded,
                    title: 'Show Viewer Count',
                    subtitle: 'Display live viewer numbers',
                    value: state.showViewerCount,
                    onChanged: cubit.showViewerCountToggled,
                  ),

                  const SizedBox(height: 14),

                  // Promo + Preview cards (static UI, easy to replace later)
                  _PromoCard(
                    title: 'First Stream Bonus',
                    message:
                        'Stream for 5+ minutes and earn \$20 bonus! Perfect time to connect with your audience.',
                  ),
                  const SizedBox(height: 12),
                  _PreviewCard(),
                ],
              ),

              // Bottom CTA
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0xCC0B102A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: state.status == GoLiveStatus.submitting
                        ? null
                        : () {
                            context.read<GoLiveCubit>().submit();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B2C),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: state.status == GoLiveStatus.submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Start Streaming',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===== UI bits used above =====

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GLSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0E1533),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownBox extends StatelessWidget {
  const _DropdownBox({
    required this.label,
    required this.hint,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return GLSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            dropdownColor: const Color(0xFF0E1533),
            onChanged: onChanged,
            icon: const Icon(Icons.expand_more_rounded, color: Colors.white70),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0E1533),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: items
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e, style: const TextStyle(color: Colors.white)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF214B2E), Color(0xFF152B1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GLSectionCard(
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 10, color: Colors.greenAccent),
            const SizedBox(width: 8),
            const Text(
              'Stream Preview',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text(
                  'Estimated Viewers',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  '12–25',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text(
                  'Best Time',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  'Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
