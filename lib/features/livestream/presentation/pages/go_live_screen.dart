import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/home/presentation/widgets/bottom_nav.dart';
import 'package:moonlight/features/livestream/domain/entities/live_category.dart';
import 'package:moonlight/features/livestream/presentation/cubits/go_live_cubit.dart';
import 'package:moonlight/features/livestream/presentation/cubits/go_live_state.dart';
import '../../../../core/ui/ui_kit.dart';

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  late final GoLiveCubit cubit;
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Handle tab navigation logic here
    switch (index) {
      case 0:
        // Navigate to Home tab content (already here)
        break;
      case 1:
        // Navigate to Go Live page
        break;
      case 2:
        // Navigate to Post creation page
        break;
      case 3:
        // Navigate to Clubs page
        break;
      case 4:
        // Navigate to Profile page
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    cubit = GetIt.I<GoLiveCubit>()..init();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        bottomNavigationBar: HomeBottomNav(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
        ),
        body: Container(
          decoration: gradientBg(),
          child: SafeArea(
            child: BlocConsumer<GoLiveCubit, GoLiveState>(
              listener: (context, state) {
                if (state.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.error!),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                if (!state.starting && state.canStart) {
                  // no-op; wire navigation to preview/live room after repo.startStreaming
                }
              },
              builder: (context, state) {
                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: false,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      centerTitle: true,
                      title: const Text(
                        'Go Live',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CoverPicker(),
                            const SizedBox(height: 18),
                            sectionTitle('Stream Title'),
                            _TitleField(),
                            const SizedBox(height: 14),
                            sectionTitle('Category'),
                            _CategoryDropdown(),
                            const SizedBox(height: 16),
                            _CameraCard(),
                            const SizedBox(height: 18),
                            sectionTitle('Stream Settings'),

                            // const SizedBox(height: 6),
                            // _SettingTile(
                            //   icon: Icons.workspace_premium_outlined,
                            //   title: 'Premium Stream',
                            //   subtitle: 'Viewers pay coins to join',
                            //   value: state.premium,
                            //   onChanged: context
                            //       .read<GoLiveCubit>()
                            //       .togglePremium,
                            // ),
                            const SizedBox(height: 14),
                            if (state.eligibleBonus) _BonusCard(),
                            const SizedBox(height: 14),
                            _PreviewCard(),
                            const SizedBox(height: 18),
                            _StartButton(),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.select((GoLiveCubit c) => c.state);
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.read<GoLiveCubit>().pickCover(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (state.coverPath != null)
                Image.file(File(state.coverPath!), fit: BoxFit.cover)
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.photo_camera_outlined,
                        color: AppColors.textSecondary,
                        size: 28,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add Cover Photo',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.divider,
                      width: 1.2,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final title = context.select((GoLiveCubit c) => c.state.title);
    return TextField(
      controller: TextEditingController(text: title)
        ..selection = TextSelection.collapsed(offset: title.length),
      onChanged: context.read<GoLiveCubit>().setTitle,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: inputDecoration('Give your stream a title'),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.select((GoLiveCubit c) => c.state);
    return DropdownButtonFormField<LiveCategory>(
      value: state.category,
      items: state.categories
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(c.name, style: const TextStyle(color: Colors.white)),
            ),
          )
          .toList(),
      onChanged: context.read<GoLiveCubit>().setCategory,
      dropdownColor: AppColors.cardDark,
      iconEnabledColor: Colors.white,
      decoration: inputDecoration('Select category'),
    );
  }
}

class _CameraCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.select((GoLiveCubit c) => c.state);
    final cubit = context.read<GoLiveCubit>();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(10),
      child: AspectRatio(
        aspectRatio: 11 / 16,
        child: Stack(
          children: [
            // Camera area
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0F24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: s.camOn && s.camReady
                      ? context.read<GoLiveCubit>().camera.buildPreview()
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                s.camOn
                                    ? Icons.hourglass_empty
                                    : Icons.videocam_off_outlined,
                                color: AppColors.textSecondary,
                                size: 36,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s.camOn
                                    ? 'Initializing camera…'
                                    : 'Camera Preview',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),

            // Right-top camera toggle
            Positioned(
              right: 8,
              top: 8,
              child: _RoundIcon(
                icon: s.camOn
                    ? Icons.videocam_outlined
                    : Icons.videocam_off_outlined,
                onTap: cubit.toggleCam,
              ),
            ),

            // Bottom-right mic toggle
            Positioned(
              right: 8,
              bottom: 8,
              child: _RoundIcon(
                icon: s.micOn
                    ? Icons.mic_none_outlined
                    : Icons.mic_off_outlined,
                onTap: cubit.toggleMic,
              ),
            ),

            // Bottom-left audio meter (visible only when mic is ON)
            if (s.micOn) Text(""),
          ],
        ),
      ),
    );
  }
}

class _AudioLevelBar extends StatelessWidget {
  final double level; // 0..1
  final bool ready;
  const _AudioLevelBar({required this.level, required this.ready});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0x22FFFFFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: LayoutBuilder(
                builder: (context, c) => Stack(
                  children: [
                    Container(width: 12, height: 8, color: Colors.transparent),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: c.maxWidth * level,
                      height: 8,
                      decoration: BoxDecoration(
                        color: ready ? Colors.white : Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          ready ? 'Audio level' : 'Testing microphone…',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x1AFFFFFF),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: AppColors.primary,
        ),
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A7F4A), Color(0xFF123A27)], // green gradient echo
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF245B3E)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.card_giftcard_outlined, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "First Stream Bonus: \nStream for 5+ minutes and earn \$20 bonus! Perfect time to connect with your audience.",
              style: TextStyle(color: Colors.white, height: 1.25),
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
    final s = context.select((GoLiveCubit c) => c.state);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Stream Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: s.previewReady
                          ? AppColors.accentGreen
                          : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.previewReady ? 'Ready' : 'Calculating...',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _stat(
                      'Estimated Viewers',
                      s.estLow > 0 ? '${s.estLow}-${s.estHigh}' : '—',
                    ),
                    const SizedBox(width: 20),
                    _stat('Best Time', s.bestTime),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<GoLiveCubit>().state;
    final canGo = state.canStart && state.devicesOk;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canGo
            ? () async {
                final dto = await context.read<GoLiveCubit>().start();
                if (dto == null) return; // guard

                // Prefer server title; fall back to local state
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

                    // Seed header counters
                    'initial_viewers': dto.initialViewers,
                    'started_at': dto.startedAt,

                    // Agora/session
                    'livestream_id': dto.livestreamId,
                    'channel': dto.channel,
                    'uid_type': dto.uidType,
                    'uid': dto.uid,
                    'app_id': dto.appId,
                    'rtc_token': dto.rtcToken,
                    'rtc_role': dto.rtcRole,
                  },
                );
              }
            : null,

        style:
            ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
            ).merge(
              ButtonStyle(
                overlayColor: MaterialStateProperty.all(Colors.white10),
                shadowColor: MaterialStateProperty.all(Colors.transparent),
                // Fancy gradient background
                backgroundColor: MaterialStateProperty.resolveWith(
                  (states) => Colors.transparent,
                ),
              ),
            ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: canGo
                  ? [AppColors.secondary, AppColors.primary2]
                  : [AppColors.divider, AppColors.divider],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            alignment: Alignment.center,
            constraints: const BoxConstraints(minHeight: 56),
            child: Text(
              'Start Streaming',
              style: TextStyle(
                color: state.canStart ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F24).withOpacity(0.9),
        border: const Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _NavItem(icon: Icons.home_outlined, label: 'Home', active: false),
          _NavItem(
            icon: Icons.videocam_outlined,
            label: 'Go Live',
            active: true,
          ),
          _NavItem(icon: Icons.add_box_outlined, label: 'Post', active: false),
          _NavItem(
            icon: Icons.groups_2_outlined,
            label: 'Clubs',
            active: false,
          ),
          _NavItem(icon: Icons.person_outline, label: 'Profile', active: false),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : AppColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
