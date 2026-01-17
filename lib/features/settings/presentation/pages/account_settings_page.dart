import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/settings/presentation/cubit/account_settings_cubit.dart';
import 'package:moonlight/features/settings/presentation/widgets/delete_account_flow.dart';
import 'package:moonlight/widgets/ml_confirm_dialog.dart';

// Import new pages
import 'package:moonlight/features/settings/presentation/pages/blocked_users_page.dart';
import 'package:moonlight/features/settings/presentation/pages/change_email_page.dart';
import 'package:moonlight/features/settings/presentation/pages/change_username_page.dart';
import 'package:moonlight/features/wallet/presentation/pages/reset_pin_page.dart';

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        if (state.status == SettingsStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        if (state.status == SettingsStatus.deleted) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final cubit = context.read<AccountSettingsCubit>();
        return Scaffold(
          backgroundColor: const Color(0xFF060522),
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
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ChangeEmailPage(),
                            ),
                          );
                        },
                      ),
                      _NavTile(
                        icon: Icons.alternate_email_rounded,
                        title: 'Change @Username',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ChangeUsernamePage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Privacy Settings',
                    children: [
                      _NavTile(
                        icon: Icons.block_rounded,
                        title: 'Blocked Users',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const BlockedUsersPage(),
                            ),
                          );
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
                        title: 'General Notifications',
                        value: state.emailEnabled,
                        onChanged: cubit.toggleEmail,
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Security',
                    children: [
                      _NavTile(
                        icon: Icons.lock_reset_rounded,
                        title: 'Set New Wallet PIN',
                        onTap: () {
                          Navigator.of(context).pushNamed(RouteNames.setNewPin);
                        },
                      ),
                      _NavTile(
                        icon: Icons.password_rounded,
                        title: 'Reset Wallet PIN',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ResetPinPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Account Management',
                    children: [
                      Container(
                        // decoration: _tileBoxDecoration,
                        child: // In AccountSettingsPage widget, update the delete tile:
                        _NavTile(
                          icon: Icons.delete_forever_rounded,
                          title: 'Delete My Account',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => DeleteAccountFlow(),
                              ),
                            );
                          },
                          trailingText: state.hasPendingDeletion
                              ? 'Scheduled (${state.daysRemaining}d)'
                              : null,
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

// ----- Private UI helpers -----

final _cardDecoration = BoxDecoration(
  color: AppColors.textWhite.withOpacity(0.2),
  borderRadius: BorderRadius.circular(16),
);

final _tileBoxDecoration = BoxDecoration(
  color: const Color(0xFF1A1A2E).withOpacity(0.6),
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
      // decoration: _tileBoxDecoration,
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
