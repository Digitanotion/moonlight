import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/settings/presentation/cubit/account_settings_cubit.dart';

import 'package:moonlight/widgets/ml_confirm_dialog.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [AppColors.primary, Color(0xFF0A0A0F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return BlocConsumer<AccountSettingsCubit, AccountSettingsState>(
      listener: (context, state) {
        if (state.status == SettingsStatus.failure && state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
        if (state.status == SettingsStatus.deleted) {
          // Wipe local and bounce to auth or onboarding as you already do in logout()
          // Call your existing Logout usecase/Bloc if you prefer.
          Navigator.of(context).pop(); // close page
        }
      },
      builder: (context, state) {
        final cubit = context.read<AccountSettingsCubit>();
        return Scaffold(
          backgroundColor: const Color.fromARGB(255, 8, 8, 67),
          // your deep gradient bg already used
          appBar: AppBar(
            elevation: 0,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textWhite,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textWhite,
              ),
            ),
            centerTitle: true,
          ),
          body: Container(
            decoration: BoxDecoration(gradient: gradient),
            child: AbsorbPointer(
              absorbing: state.status == SettingsStatus.loading,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _Section(
                    title: 'Account Information',
                    children: [
                      _NavTile(
                        icon: Icons.email_rounded,
                        title: 'Change Email',
                        onTap: () {
                          /* TODO */
                        },
                      ),
                      _NavTile(
                        icon: Icons.lock_rounded,
                        title: 'Change Password',
                        onTap: () {
                          /* TODO */
                        },
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Privacy Settings',
                    children: [
                      _NavTile(
                        icon: Icons.chat_bubble_rounded,
                        title: 'Who Can Message You',
                        trailingText: 'Everyone',
                        onTap: () {
                          /* TODO */
                        },
                      ),
                      _NavTile(
                        icon: Icons.visibility_rounded,
                        title: 'Who Can See My Profile',
                        trailingText: 'Everyone',
                        onTap: () {
                          /* TODO */
                        },
                      ),
                      _NavTile(
                        icon: Icons.block_rounded,
                        title: 'Blocked Users',
                        onTap: () {
                          /* TODO */
                        },
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Notifications',
                    children: [
                      _SwitchTile(
                        icon: Icons.notifications_rounded,
                        title: 'Push Notifications',
                        value: state.pushEnabled,
                        onChanged: cubit.togglePush,
                      ),
                      _SwitchTile(
                        icon: Icons.mark_email_read_rounded,
                        title: 'Email Notifications',
                        value: state.emailEnabled,
                        onChanged: cubit.toggleEmail,
                      ),
                      _SwitchTile(
                        icon: Icons.live_tv_rounded,
                        title: 'Livestream Alerts',
                        value: state.liveAlertsEnabled,
                        onChanged: cubit.toggleLiveAlerts,
                      ),
                      _SwitchTile(
                        icon: Icons.card_giftcard_rounded,
                        title: 'Gift/Tip Received Alerts',
                        value: state.giftAlertsEnabled,
                        onChanged: cubit.toggleGiftAlerts,
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Security',
                    children: [
                      _NavTile(
                        icon: Icons.pin_rounded,
                        title: 'Reset PIN',
                        onTap: () {
                          /* TODO */
                        },
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Account Management',
                    children: [
                      _SwitchTile(
                        icon: Icons.pause_rounded,
                        title: 'Deactivate Account',
                        value: state.isDeactivated,
                        onChanged: (v) {
                          if (v) {
                            showDialog(
                              context: context,
                              builder: (_) => MLConfirmDialog(
                                icon: Icons.person_off_rounded,
                                title: 'Deactivate account?',
                                message:
                                    "You can reactivate later by logging in again.",
                                confirmText: 'Deactivate',
                                confirmColor: const Color(0xFF6B7280),
                                onConfirm: () => cubit.performDeactivate(),
                              ),
                            );
                          } else {
                            cubit.performReactivate();
                          }
                        },
                      ),
                      // Danger zone
                      Container(
                        decoration: _tileBoxDecoration,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: const Icon(
                            Icons.delete_forever_rounded,
                            color: Color(0xFFFF6B6B),
                          ),
                          title: const Text(
                            'Delete My Account',
                            style: TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFFF6B6B),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => MLConfirmDialog(
                                icon: Icons.person_rounded,
                                title: 'Permanently delete account?',
                                message:
                                    "This action cannot be undone. You’ll lose all posts, coins, and club memberships.",
                                confirmText: 'Delete account',
                                confirmColor: const Color(0xFFE24D4D),
                                onConfirm: () => cubit.performDelete(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  if (state.status == SettingsStatus.loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ----- Private UI helpers to match your visual style -----

final _cardDecoration = BoxDecoration(
  color: AppColors.textWhite.withOpacity(0.2),
  borderRadius: BorderRadius.circular(16),
);

final _tileBoxDecoration = BoxDecoration(
  color: const Color.fromARGB(255, 195, 0, 0).withOpacity(0),
  borderRadius: BorderRadius.circular(14),
);

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: _cardDecoration,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: children
                  .expand(
                    (w) => [
                      w,
                      if (w != children.last)
                        const Divider(height: 1, color: Color(0x22FFFFFF)),
                    ],
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _tileBoxDecoration,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null)
              Text(
                trailingText!,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _tileBoxDecoration,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: const Color(0xFF5C7CF8),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.transparent,
        ),
      ),
    );
  }
}
