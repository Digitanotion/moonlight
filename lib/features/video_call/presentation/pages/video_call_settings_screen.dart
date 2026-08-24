// lib/features/video_call/presentation/pages/video_call_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/video_call/domain/repositories/video_call_repository.dart';

class VideoCallSettingsScreen extends StatefulWidget {
  const VideoCallSettingsScreen({super.key});

  @override
  State<VideoCallSettingsScreen> createState() =>
      _VideoCallSettingsScreenState();
}

class _VideoCallSettingsScreenState extends State<VideoCallSettingsScreen> {
  final _repo = sl<VideoCallRepository>();

  bool _online = false;
  bool _enabled = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Bug: these were previously always hardcoded to false, never actually
    // read from the real, current user data — the screen only ever WROTE
    // toggle changes, it never READ the existing state on open. Both
    // fields already exist in every /profile/me response (confirmed via
    // UserResource), just weren't wired into the User entity/model at
    // all before now.
    final user = sl<CurrentUserService>().currentUser;
    _online = user?.isVideoCallOnline ?? false;
    _enabled = user?.videoCallEnabled ?? false;
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() {
      _online = value; // optimistic
      _busy = true;
      _error = null;
    });
    try {
      await _repo.toggleOnline(value);
      // Keep the cached CurrentUserService in sync with what the
      // backend just confirmed — without this, the API call succeeds
      // but re-opening this screen later reads the STALE cached user
      // object (only refreshed at login/app-launch), showing the old
      // value again even though the change genuinely took effect.
      final service = sl<CurrentUserService>();
      final current = service.currentUser;
      if (current != null) {
        service.setUser(current.copyWith(isVideoCallOnline: value));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _online = !value; // revert on failure
        _error = 'Could not update your status. Try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() {
      _enabled = value;
      _busy = true;
      _error = null;
    });
    try {
      await _repo.toggleEnabled(value);
      final service = sl<CurrentUserService>();
      final current = service.currentUser;
      if (current != null) {
        service.setUser(current.copyWith(videoCallEnabled: value));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enabled = !value;
        _error = 'Could not update your setting. Try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _boost(String duration, int cost) async {
    final confirmed = await _confirmSheet(
      title: duration == '1_week' ? 'Boost for 1 week' : 'Boost for 2 days',
      body:
          'Your profile will be featured at the top of the video call directory for ${duration == '1_week' ? '7 days' : '2 days'}.',
      confirmLabel: 'Spend $cost coins',
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.boost(duration);
      if (!mounted) return;
      _showSnack('Profile boosted!', success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Boost failed — check your coin balance.', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _broadcast(String audience) async {
    final isPaid = audience == 'all_males';
    final confirmed = await _confirmSheet(
      title: isPaid ? 'Notify all users' : 'Notify your followers',
      body: isPaid
          ? 'Every male user on Moonlight will get a push notification that you\'re online. This costs 100 coins.'
          : 'Your followers will get a free push notification that you\'re online.',
      confirmLabel: isPaid ? 'Send for 100 coins' : 'Send for free',
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.broadcast(audience: audience, message: 'I\'m online now!');
      if (!mounted) return;
      _showSnack('Notification sent!', success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not send notification.', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.accentGreen : AppColors.textRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<bool?> _confirmSheet({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: AppTextStyles.body.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary_,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navy, AppColors.dark],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Video Call Settings',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              _SectionCard(
                child: Column(
                  children: [
                    _ToggleRow(
                      icon: Icons.videocam_rounded,
                      iconColor: _online
                          ? AppColors.accentGreen
                          : Colors.white38,
                      title: 'Go online for calls',
                      subtitle:
                          'Appear in the video call directory and be reachable.',
                      value: _online,
                      onChanged: _busy ? null : _toggleOnline,
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    _ToggleRow(
                      icon: Icons.person_rounded,
                      iconColor: _enabled
                          ? AppColors.primary2
                          : Colors.white38,
                      title: 'Show call button on my profile',
                      subtitle: 'Let visitors call you from your profile page.',
                      value: _enabled,
                      onChanged: _busy ? null : _toggleEnabled,
                    ),
                  ],
                ),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textRed,
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              Text(
                'Get discovered faster',
                style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),

              _ActionCard(
                icon: Icons.bolt_rounded,
                iconColor: AppColors.primary_,
                title: 'Boost your profile',
                subtitle: 'Front-row placement in the directory',
                trailing: Row(
                  children: [
                    _MiniButton(
                      label: '2 days\n20 coins',
                      onTap: _busy ? null : () => _boost('2_days', 20),
                    ),
                    const SizedBox(width: 8),
                    _MiniButton(
                      label: '1 week\n60 coins',
                      onTap: _busy ? null : () => _boost('1_week', 60),
                      highlighted: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _ActionCard(
                icon: Icons.campaign_rounded,
                iconColor: AppColors.info,
                title: 'Let people know you\'re online',
                subtitle: 'Send a notification right now',
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _MiniButton(
                      label: 'Followers\nFree',
                      onTap: _busy ? null : () => _broadcast('followers'),
                    ),
                    const SizedBox(height: 8),
                    _MiniButton(
                      label: 'Everyone\n100 coins',
                      onTap: _busy ? null : () => _broadcast('all_males'),
                      highlighted: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.small.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.accentGreen,
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.small.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  const _MiniButton({
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: highlighted
              ? const LinearGradient(
                  colors: [AppColors.primary_, AppColors.primary2],
                )
              : null,
          color: highlighted ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}