// lib/features/offerwall/presentation/pages/offerwall_dashboard_screen.dart
//
// The "Earn Cash" dashboard — separate from the main wallet, per spec
// ("a separate dashboard like we have in club where earned coins go to and
// from where they can make withdrawals"). Balance, earnings history,
// withdrawal history, and the withdraw flow (min $15 / max $100 / once a
// week, admin-approved — never automatic) all live here.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/offerwall/presentation/cubit/offerwall_cubit.dart';
import 'package:moonlight/widgets/top_snack.dart';

class OfferwallDashboardScreen extends StatelessWidget {
  const OfferwallDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OfferwallCubit>(
      create: (_) => sl<OfferwallCubit>()
        ..load()
        ..loadTransactions()
        ..loadWithdrawals(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();
  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openWithdrawSheet(BuildContext context) async {
    final cubit = context.read<OfferwallCubit>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _WithdrawSheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My Earnings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: BlocConsumer<OfferwallCubit, OfferwallState>(
        listenWhen: (p, n) => p.error != n.error && n.error != null,
        listener: (context, state) {
          if (state.error != null) TopSnack.error(context, state.error!);
        },
        builder: (context, state) {
          final cubit = context.read<OfferwallCubit>();
          return RefreshIndicator(
            onRefresh: () async {
              await cubit.load();
              await cubit.loadTransactions();
              await cubit.loadWithdrawals();
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _BalanceCard(
                    balanceUsd: state.balanceUsd,
                    lifetimeCents: state.lifetimeEarnedUsdCents,
                    onWithdraw: () => _openWithdrawSheet(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.dark,
                    child: TabBar(
                      controller: _tabs,
                      indicatorColor: const Color(0xFF1FBF75),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white38,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                      tabs: const [
                        Tab(text: 'Earnings'),
                        Tab(text: 'Withdrawals'),
                      ],
                    ),
                  ),
                ),
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _EarningsList(items: state.transactions),
                      _WithdrawalsList(items: state.withdrawals),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balanceUsd;
  final int lifetimeCents;
  final VoidCallback onWithdraw;

  const _BalanceCard({
    required this.balanceUsd,
    required this.lifetimeCents,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF0E8F5B), Color(0xFF1FBF75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1FBF75).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available balance',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Text(
              '\$${balanceUsd.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lifetime earned: \$${(lifetimeCents / 100).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onWithdraw,
                child: const Text(
                  'Withdraw',
                  style: TextStyle(
                    color: Color(0xFF0E8F5B),
                    fontWeight: FontWeight.w800,
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

class _EarningsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _EarningsList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.savings_rounded,
        text: 'No earnings yet — complete a task to see it here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final t = items[i];
        final provider = (t['provider'] ?? '').toString();
        final userCents = (t['user_usd_cents'] ?? 0) as int;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(
                  0xFF1FBF75,
                ).withValues(alpha: 0.15),
                child: const Icon(
                  Icons.arrow_downward_rounded,
                  color: Color(0xFF1FBF75),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.isEmpty
                          ? 'Task reward'
                          : '${provider[0].toUpperCase()}${provider.substring(1)} task',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      (t['created_at'] ?? '').toString(),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '+\$${(userCents / 100).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF1FBF75),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WithdrawalsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _WithdrawalsList({required this.items});

  Color _statusColor(String status) => switch (status) {
    'pending' => const Color(0xFFF5A623),
    'approved' || 'paid' => const Color(0xFF1FBF75),
    'declined' || 'failed' => const Color(0xFFEF4444),
    _ => Colors.white38,
  };

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_rounded,
        text: 'No withdrawal requests yet.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final w = items[i];
        final status = (w['status'] ?? 'pending').toString();
        final cents = (w['amount_usd_cents'] ?? 0) as int;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${(cents / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      (w['created_at'] ?? '').toString(),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white24, size: 40),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet();
  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankCodeCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _paypalEmailCtrl = TextEditingController();
  String _method = 'flutterwave';
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankCodeCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    _paypalEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(OfferwallState state) async {
    final amountUsd = double.tryParse(_amountCtrl.text.trim());
    if (amountUsd == null) {
      TopSnack.error(context, 'Enter a valid amount.');
      return;
    }
    final cents = (amountUsd * 100).round();

    if (cents < state.minWithdrawUsdCents ||
        cents > state.maxWithdrawUsdCents) {
      TopSnack.error(
        context,
        'Amount must be between \$${(state.minWithdrawUsdCents / 100).toStringAsFixed(0)} '
        'and \$${(state.maxWithdrawUsdCents / 100).toStringAsFixed(0)}.',
      );
      return;
    }

    if (_method == 'flutterwave' &&
        (_bankCodeCtrl.text.trim().isEmpty ||
            _accountNumberCtrl.text.trim().isEmpty ||
            _accountNameCtrl.text.trim().isEmpty)) {
      TopSnack.error(context, 'Fill in your bank details.');
      return;
    }
    if (_method == 'paypal' && _paypalEmailCtrl.text.trim().isEmpty) {
      TopSnack.error(context, 'Enter your PayPal email.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final message = await context.read<OfferwallCubit>().requestWithdrawal(
        amountUsdCents: cents,
        paymentMethod: _method,
        bankAccountName: _method == 'flutterwave'
            ? _accountNameCtrl.text.trim()
            : null,
        bankAccountNumber: _method == 'flutterwave'
            ? _accountNumberCtrl.text.trim()
            : null,
        bankName: _method == 'flutterwave' ? _bankNameCtrl.text.trim() : null,
        bankCode: _method == 'flutterwave' ? _bankCodeCtrl.text.trim() : null,
        paypalEmail: _method == 'paypal' ? _paypalEmailCtrl.text.trim() : null,
      );

      if (!mounted) return;
      Navigator.pop(context); // close the sheet first

      // The spec explicitly calls for a POPUP here, not just a toast.
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF0E1024),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Withdrawal requested',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF75),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) TopSnack.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OfferwallCubit>().state;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E1024),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Withdraw earnings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Min \$${(state.minWithdrawUsdCents / 100).toStringAsFixed(0)} · '
                'Max \$${(state.maxWithdrawUsdCents / 100).toStringAsFixed(0)} per week',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _field(
                _amountCtrl,
                'Amount (USD)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'flutterwave', label: Text('Bank')),
                  ButtonSegment(value: 'paypal', label: Text('PayPal')),
                ],
                selected: {_method},
                onSelectionChanged: (s) => setState(() => _method = s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: const Color(0xFF1FBF75),
                  selectedForegroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  foregroundColor: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              if (_method == 'flutterwave') ...[
                _field(_bankNameCtrl, 'Bank name'),
                const SizedBox(height: 10),
                _field(_bankCodeCtrl, 'Bank code'),
                const SizedBox(height: 10),
                _field(_accountNumberCtrl, 'Account number'),
                const SizedBox(height: 10),
                _field(_accountNameCtrl, 'Account name'),
              ] else
                _field(_paypalEmailCtrl, 'PayPal email'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF75),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _submitting ? null : () => _submit(state),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Text(
                          'Request withdrawal',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}
