// lib/features/offerwall/presentation/pages/daily_tasks_screen.dart
//
// Locked (activation) state + unlocked Daily Tasks surface, per the client
// spec: "Activate your participation with one time 100 coins maintenance
// requirement to start earning cash daily for life. You will be able to
// withdraw your earnings every week."
//
// The two provider tabs are honest placeholders until Adjoe/Torox hand over
// real SDK keys — building a fake-working offerwall would be worse than
// telling the user it's finishing setup. Swapping each _ProviderOfferwall
// placeholder for a real SDK embed (native surface or WebView) is a
// self-contained change once credentials exist; nothing else here needs to
// move.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/offerwall/presentation/cubit/offerwall_cubit.dart';
import 'package:moonlight/widgets/top_snack.dart';

class DailyTasksScreen extends StatelessWidget {
  const DailyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OfferwallCubit>(
      create: (_) => sl<OfferwallCubit>()..load(),
      child: const _DailyTasksView(),
    );
  }
}

class _DailyTasksView extends StatefulWidget {
  const _DailyTasksView();

  @override
  State<_DailyTasksView> createState() => _DailyTasksViewState();
}

class _DailyTasksViewState extends State<_DailyTasksView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _activate(BuildContext context) async {
    final cubit = context.read<OfferwallCubit>();
    final coins = cubit.state.activationCostCoins;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0E1024),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Activate Daily Tasks',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'This uses $coins coins as a one-time activation fee. '
          'You\'ll then be able to earn cash daily for life and withdraw '
          'your earnings every week.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1FBF75),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await cubit.activate();
    if (!context.mounted) return;
    if (ok) {
      TopSnack.success(context, 'Activated! Start earning below.');
    } else {
      TopSnack.error(context, cubit.state.error ?? 'Could not activate.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        elevation: 0,
        title: const Text(
          'Daily Tasks',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          BlocBuilder<OfferwallCubit, OfferwallState>(
            buildWhen: (p, n) => p.activated != n.activated,
            builder: (context, state) {
              if (!state.activated) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'My Earnings',
                icon: const Icon(Icons.account_balance_wallet_rounded),
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.offerwallDashboard),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<OfferwallCubit, OfferwallState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1FBF75)),
            );
          }

          if (!state.activated) {
            return _ActivationGate(
              costCoins: state.activationCostCoins,
              activating: state.activating,
              onActivate: () => _activate(context),
            );
          }

          return Column(
            children: [
              Container(
                color: AppColors.dark,
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: const Color(0xFF1FBF75),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Adjoe'),
                    Tab(text: 'Torox'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: const [
                    _ProviderOfferwall(providerName: 'Adjoe'),
                    _ProviderOfferwall(providerName: 'Torox'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivationGate extends StatelessWidget {
  final int costCoins;
  final bool activating;
  final VoidCallback onActivate;

  const _ActivationGate({
    required this.costCoins,
    required this.activating,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E8F5B), Color(0xFF1FBF75)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1FBF75).withValues(alpha: 0.35),
                    blurRadius: 24,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text('🔒', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Unlock Daily Tasks',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Activate your participation with one time $costCoins coins '
              'maintenance requirement to start earning cash daily for life. '
              'You will be able to withdraw your earnings every week.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1FBF75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: activating ? null : onActivate,
                child: activating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : Text(
                        'Activate with $costCoins coins',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
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

/// Honest placeholder for one provider's offerwall surface. Swap the body
/// for the real SDK/WebView once that vendor's keys are wired in
/// (config/offerwall.php on the API side + this widget on the client side).
class _ProviderOfferwall extends StatelessWidget {
  final String providerName;
  const _ProviderOfferwall({required this.providerName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              '$providerName tasks are finishing setup',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We\'re putting the final touches on this partner\'s tasks. '
              'Check back soon — your activation is already saved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
