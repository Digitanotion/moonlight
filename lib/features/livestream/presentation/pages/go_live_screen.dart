// lib/features/livestream/presentation/pages/go_live_screen.dart
//
// Go Live — set up and start a livestream. You're "on stage" from the first
// second: your camera fills the screen, the few things to fill in sit in one
// frosted panel at the bottom, and Go Live counts you in (3-2-1) while the
// stream is being created.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/widgets/styled_banner_ad.dart';
import 'package:moonlight/features/livestream/domain/entities/live_category.dart';
import 'package:moonlight/features/livestream/presentation/cubits/go_live_cubit.dart';
import 'package:moonlight/features/livestream/presentation/cubits/go_live_state.dart';
import 'package:moonlight/features/livestream/presentation/widgets/searchable_category_dropdown.dart';

const _rose = Color(0xFFFF2D55);
const _ember = Color(0xFFFF7A00);
const _violet = Color(0xFF8E2DE2);
const _night = Color(0xFF0A0920);

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  late final GoLiveCubit cubit;

  @override
  void initState() {
    super.initState();
    cubit = GetIt.I<GoLiveCubit>()..init();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _night,
          resizeToAvoidBottomInset: true,
          body: BlocListener<GoLiveCubit, GoLiveState>(
            listenWhen: (p, n) => n.error != null && p.error != n.error,
            listener: (context, state) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const _Stage(),
          ),
        ),
      ),
    );
  }
}

class _Stage extends StatefulWidget {
  const _Stage();

  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> {
  int? _count; // 3-2-1 countdown on screen

  Future<void> _goLive() async {
    final cubit = context.read<GoLiveCubit>();
    final state = cubit.state;
    if (!state.canStart || !state.devicesOk || _count != null) return;
    HapticFeedback.mediumImpact();

    // Create the stream while counting the host in.
    final starting = cubit.start();
    for (final n in [3, 2, 1]) {
      if (!mounted) return;
      setState(() => _count = n);
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 800));
    }
    final dto = await starting;
    if (!mounted) return;
    setState(() => _count = null);
    if (dto == null) return; // error shown by the listener

    final topic = (dto.streamTitle.isNotEmpty)
        ? dto.streamTitle
        : (state.title.isNotEmpty ? state.title : 'Live');

    Navigator.pushNamed(
      context,
      RouteNames.liveHost,
      arguments: {
        'host_name': dto.hostDisplayName,
        'host_uuid': dto.hostUuid,
        'host_badge': dto.hostBadge,
        'avatar_url': dto.hostAvatarUrl,
        'topic': topic,
        'initial_viewers': dto.initialViewers,
        'started_at': dto.startedAt,
        'livestream_id': dto.livestreamId,
        'channel': dto.channel,
        'uid_type': dto.uidType,
        'uid': dto.uid,
        'app_id': dto.appId,
        'rtc_token': dto.rtcToken,
        'rtc_role': dto.rtcRole,
        'mic_on': dto.micOn,
        'cam_on': dto.camOn,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GoLiveCubit>().state;
    final cubit = context.read<GoLiveCubit>();
    final top = MediaQuery.of(context).padding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── You, full screen ────────────────────────────────────────────
        if (s.camOn && s.camReady)
          cubit.camera.buildPreview()
        else
          _CameraOff(camOn: s.camOn),

        // Soft shade so text always reads over any camera image.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.18, 0.5, 1],
              colors: [
                Color(0xAA000000),
                Colors.transparent,
                Colors.transparent,
                Color(0xE6000000),
              ],
            ),
          ),
        ),

        // ── Top bar ─────────────────────────────────────────────────────
        Positioned(
          top: top + 8,
          left: 12,
          right: 12,
          child: Row(
            children: [
              _GlassIcon(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              const _PreviewPill(),
              const Spacer(),
              const SizedBox(width: 44),
            ],
          ),
        ),

        // ── Camera & mic, down the right ────────────────────────────────
        Positioned(
          top: top + 72,
          right: 12,
          child: Column(
            children: [
              _GlassIcon(
                icon: s.camOn
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                label: s.camOn ? 'Camera' : 'Camera off',
                off: !s.camOn,
                onTap: cubit.toggleCam,
              ),
              const SizedBox(height: 14),
              _GlassIcon(
                icon: s.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                label: s.micOn ? 'Mic' : 'Muted',
                off: !s.micOn,
                level: s.micOn ? s.micLevel : null,
                onTap: cubit.toggleMic,
              ),
            ],
          ),
        ),

        // ── Details + Go Live ───────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _DetailsPanel(),
                  const SizedBox(height: 10),
                  const StyledBannerAd(),
                  const SizedBox(height: 10),
                  _GoLiveButton(onTap: _goLive),
                ],
              ),
            ),
          ),
        ),

        // ── 3-2-1 ───────────────────────────────────────────────────────
        if (_count != null) _Countdown(n: _count!),
      ],
    );
  }
}

// ── pieces ───────────────────────────────────────────────────────────────

class _CameraOff extends StatelessWidget {
  final bool camOn;
  const _CameraOff({required this.camOn});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1446), _night, Color(0xFF2A0F2E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                camOn
                    ? Icons.hourglass_top_rounded
                    : Icons.videocam_off_rounded,
                color: Colors.white70,
                size: 38,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              camOn ? 'Waking up your camera…' : 'Camera is off — audio only',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPill extends StatefulWidget {
  const _PreviewPill();

  @override
  State<_PreviewPill> createState() => _PreviewPillState();
}

class _PreviewPillState extends State<_PreviewPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _rose,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Ready when you are',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GoLiveCubit>().state;
    return _Glass(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CoverThumb(path: s.coverPath),
              const SizedBox(width: 12),
              const Expanded(child: _TitleField()),
            ],
          ),
          const SizedBox(height: 12),
          _CategoryChips(selected: s.category, categories: s.categories),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(
                icon: Icons.groups_rounded,
                text: s.estLow > 0
                    ? '${s.estLow}–${s.estHigh} likely viewers'
                    : (s.previewReady ? 'Fresh audience' : 'Reading the room…'),
              ),
              if (s.bestTime.isNotEmpty)
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  text: 'Best time ${s.bestTime}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  final String? path;
  const _CoverThumb({this.path});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<GoLiveCubit>().pickCover(),
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: path != null
            ? Image.file(File(path!), fit: BoxFit.cover)
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    color: Colors.white70,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Cover',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TitleField extends StatefulWidget {
  const _TitleField();

  @override
  State<_TitleField> createState() => _TitleFieldState();
}

class _TitleFieldState extends State<_TitleField> {
  late final TextEditingController _c = TextEditingController(
    text: context.read<GoLiveCubit>().state.title,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      onChanged: context.read<GoLiveCubit>().setTitle,
      maxLength: 80,
      maxLines: 2,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      cursorColor: _rose,
      decoration: const InputDecoration(
        hintText: 'What\'s your live about?',
        hintStyle: TextStyle(
          color: Colors.white54,
          fontWeight: FontWeight.w600,
        ),
        counterText: '',
        border: InputBorder.none,
        isDense: true,
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final LiveCategory? selected;
  final List<LiveCategory> categories;
  const _CategoryChips({required this.selected, required this.categories});

  Future<void> _more(BuildContext context) async {
    final cubit = context.read<GoLiveCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14101F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(c).viewInsets.bottom,
        ),
        child: SearchableCategoryDropdown(
          value: selected,
          hintText: 'Search categories',
          onChanged: (cat) {
            cubit.setCategory(cat);
            Navigator.pop(c);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GoLiveCubit>();
    // Selected first, then the rest — one swipeable row.
    final list = [
      if (selected != null) selected!,
      ...categories.where((c) => c.id != selected?.id),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (final c in list.take(12))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Chip(
                label: '${c.icon} ${c.name}',
                selected: c.id == selected?.id,
                onTap: () {
                  HapticFeedback.selectionClick();
                  cubit.setCategory(c);
                },
              ),
            ),
          _Chip(label: '🔍 More', selected: false, onTap: () => _more(context)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? const LinearGradient(colors: [_rose, _ember])
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white60),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _GoLiveButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GoLiveButton({required this.onTap});

  @override
  State<_GoLiveButton> createState() => _GoLiveButtonState();
}

class _GoLiveButtonState extends State<_GoLiveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<GoLiveCubit>().state;
    final ready = s.canStart && s.devicesOk && !s.starting;
    final hint = s.title.trim().isEmpty
        ? 'Add a title to go live'
        : (s.category == null ? 'Pick a category to go live' : null);

    return Column(
      children: [
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              hint,
              style: const TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
          ),
        AnimatedBuilder(
          animation: _glow,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: ready
                  ? [
                      BoxShadow(
                        color: _rose.withValues(
                          alpha: 0.35 + 0.3 * _glow.value,
                        ),
                        blurRadius: 18 + 14 * _glow.value,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: child,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: ready ? widget.onTap : null,
              child: Ink(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: ready
                        ? const [_rose, _ember]
                        : [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.12),
                          ],
                  ),
                ),
                child: Center(
                  child: s.starting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sensors_rounded,
                              color: ready ? Colors.white : Colors.white38,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'GO LIVE',
                              style: TextStyle(
                                color: ready ? Colors.white : Colors.white38,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Countdown extends StatelessWidget {
  final int n;
  const _Countdown({required this.n});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(n),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOutBack,
          builder: (_, t, _) => Opacity(
            opacity: (1.4 - t).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.4 + t,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [_rose, _ember, _violet],
                ).createShader(r),
                child: Text(
                  '$n',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 140,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final bool off;
  final double? level; // mic level 0..1 → glowing ring

  const _GlassIcon({
    required this.icon,
    required this.onTap,
    this.label,
    this.off = false,
    this.level,
  });

  @override
  Widget build(BuildContext context) {
    final l = (level ?? 0).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: level != null && l > 0.05
                  ? [
                      BoxShadow(
                        color: const Color(0xFF39D98A).withValues(alpha: 0.7),
                        blurRadius: 6 + 18 * l,
                        spreadRadius: 1 + 3 * l,
                      ),
                    ]
                  : const [],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: off
                        ? _rose.withValues(alpha: 0.75)
                        : Colors.white.withValues(alpha: 0.14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  const _Glass({
    required this.child,
    required this.radius,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: child,
        ),
      ),
    );
  }
}
