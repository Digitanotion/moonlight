// lib/features/offerwall/presentation/pages/offerwall_dashboard_screen.dart
//
// The "Earn Cash" dashboard — separate from the main wallet, per spec
// ("a separate dashboard like we have in club where earned coins go to and
// from where they can make withdrawals"). Balance, earnings history,
// withdrawal history, and the withdraw flow (min $15 / max $100 / once a
// week, admin-approved — never automatic) all live here.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/offerwall/presentation/cubit/offerwall_cubit.dart';
import 'package:moonlight/features/withdrawal/domain/repositories/withdrawal_repository.dart';
import 'package:moonlight/widgets/top_snack.dart';

import 'package:moonlight/core/widgets/app_logo_loader.dart';

// Nigeria NUBAN is always exactly 10 digits — resolve immediately on hit,
// same threshold the main wallet withdrawal screen uses.
const int _kNubanLength = 10;
const String _kOfferwallBankCountry = 'Nigeria';

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
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final String _method = 'flutterwave'; // PayPal is disabled — see chips below.
  bool _submitting = false;

  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _selectedBank;
  bool _loadingBanks = false;
  bool _resolvingAccountName = false;
  String? _accountNameError;
  Timer? _accountResolutionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBanks());
  }

  @override
  void dispose() {
    _accountResolutionTimer?.cancel();
    _amountCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  // ── Bank fetch + account-name resolution ──────────────────────────────────
  // Same smooth flow as the main wallet withdrawal screen: select a bank,
  // type the account number, and the account name auto-fills.

  Future<void> _loadBanks() async {
    setState(() {
      _loadingBanks = true;
      _selectedBank = null;
      _banks = [];
      _accountNameCtrl.clear();
      _accountNameError = null;
    });
    try {
      final banks = await sl<WithdrawalRepository>().fetchBanks(
        _kOfferwallBankCountry,
      );
      if (mounted) setState(() => _banks = banks);
    } catch (e) {
      if (mounted) TopSnack.error(context, 'Could not load banks: $e');
    } finally {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  void _onBankSelected(Map<String, dynamic> bank) {
    setState(() {
      _selectedBank = bank;
      _accountNameCtrl.clear();
      _accountNameError = null;
      _resolvingAccountName = false;
    });
    _accountResolutionTimer?.cancel();

    final number = _accountNumberCtrl.text.trim();
    if (number.length >= _kNubanLength) {
      _triggerResolution(number, bank);
    }
  }

  void _onAccountNumberChanged(String value) {
    final number = value.trim();
    final bank = _selectedBank;

    setState(() {
      _accountNameCtrl.clear();
      _accountNameError = null;
      _resolvingAccountName = false;
    });
    _accountResolutionTimer?.cancel();

    if (bank == null || number.length < _kNubanLength) return;

    if (number.length == _kNubanLength) {
      _triggerResolution(number, bank);
      return;
    }

    setState(() => _resolvingAccountName = true);
    _accountResolutionTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _triggerResolution(number, bank);
    });
  }

  Future<void> _triggerResolution(
    String number,
    Map<String, dynamic> bank,
  ) async {
    setState(() {
      _resolvingAccountName = true;
      _accountNameError = null;
    });
    try {
      final name = await sl<WithdrawalRepository>().resolveAccountName(
        accountNumber: number,
        bankCode: bank['code']?.toString() ?? '',
      );
      if (!mounted) return;
      setState(() {
        _accountNameCtrl.text = name;
        _resolvingAccountName = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accountNameCtrl.clear();
        _resolvingAccountName = false;
        _accountNameError =
            'Could not verify this account. Check the '
            'account number and bank.';
      });
    }
  }

  void _openBankSearchSheet() {
    if (_banks.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1533),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OfferwallBankSearchSheet(
        banks: _banks,
        onSelected: (bank) {
          Navigator.pop(context);
          _onBankSelected(bank);
        },
      ),
    );
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

    if (_selectedBank == null ||
        _accountNumberCtrl.text.trim().isEmpty ||
        _accountNameCtrl.text.trim().isEmpty) {
      TopSnack.error(context, 'Fill in your bank details.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final message = await context.read<OfferwallCubit>().requestWithdrawal(
        amountUsdCents: cents,
        paymentMethod: _method,
        bankAccountName: _accountNameCtrl.text.trim(),
        bankAccountNumber: _accountNumberCtrl.text.trim(),
        bankName: _selectedBank?['name']?.toString() ?? '',
        bankCode: _selectedBank?['code']?.toString() ?? '',
        bankCountry: _kOfferwallBankCountry,
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
              Row(
                children: [
                  Expanded(
                    child: _OfferwallMethodChip(
                      label: 'Bank Transfer',
                      icon: Icons.account_balance_rounded,
                      selected: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OfferwallMethodChip(
                      label: 'PayPal',
                      icon: Icons.send_to_mobile_rounded,
                      selected: false,
                      disabled: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _bankSelector(),
              const SizedBox(height: 10),
              _accountNumberField(),
              const SizedBox(height: 10),
              _accountNameField(),
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
                          child: AppLogoLoader(),
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

  // ── Searchable bank selector ───────────────────────────────────────────────

  Widget _bankSelector() {
    return GestureDetector(
      onTap: _loadingBanks || _banks.isEmpty ? null : _openBankSearchSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedBank != null
                ? const Color(0xFF1FBF75).withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _loadingBanks
                  ? const Row(
                      children: [
                        SizedBox(width: 16, height: 16, child: AppLogoLoader()),
                        SizedBox(width: 12),
                        Text(
                          'Loading banks…',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    )
                  : _banks.isEmpty
                  ? Row(
                      children: [
                        const Text(
                          'No banks loaded',
                          style: TextStyle(color: Colors.white38),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _loadBanks,
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Color(0xFF1FBF75)),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _selectedBank?['name']?.toString() ??
                          'Tap to select your bank',
                      style: TextStyle(
                        color: _selectedBank != null
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 15,
                      ),
                    ),
            ),
            if (!_loadingBanks && _banks.isNotEmpty)
              Icon(
                Icons.search,
                color: _selectedBank != null
                    ? const Color(0xFF1FBF75)
                    : Colors.white38,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  // ── Account number field ───────────────────────────────────────────────────

  Widget _accountNumberField() {
    return TextField(
      controller: _accountNumberCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(16),
      ],
      style: const TextStyle(color: Colors.white),
      onChanged: _onAccountNumberChanged,
      decoration: InputDecoration(
        labelText: 'Account number',
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

  // ── Account name field (read-only, auto-populated) ─────────────────────────

  Widget _accountNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _accountNameCtrl,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Account name',
            hintText: _resolvingAccountName
                ? 'Verifying…'
                : 'Auto-filled from your account number',
            labelStyle: const TextStyle(color: Colors.white54),
            hintStyle: const TextStyle(color: Colors.white30),
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
            suffixIcon: _resolvingAccountName
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: AppLogoLoader(),
                    ),
                  )
                : (_accountNameCtrl.text.isNotEmpty
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF1FBF75),
                        )
                      : null),
          ),
        ),
        if (_accountNameError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _accountNameError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
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

// ── Payment method chip ────────────────────────────────────────────────────
// PayPal stays visible but disabled — same treatment as the main wallet
// withdrawal screen: grayed out, a help icon, and a "not available" message
// on tap instead of being selectable.

class _OfferwallMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool disabled;

  const _OfferwallMethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.disabled = false,
  });

  void _showDisabledMessage(BuildContext context) {
    TopSnack.info(context, 'PayPal is not available at the moment.');
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = selected && !disabled;
    return GestureDetector(
      onTap: disabled ? () => _showDisabledMessage(context) : null,
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1FBF75)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (disabled) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showDisabledMessage(context),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    size: 16,
                    color: Colors.white38,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bank search sheet ───────────────────────────────────────────────────────

class _OfferwallBankSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> banks;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _OfferwallBankSearchSheet({
    required this.banks,
    required this.onSelected,
  });

  @override
  State<_OfferwallBankSearchSheet> createState() =>
      _OfferwallBankSearchSheetState();
}

class _OfferwallBankSearchSheetState extends State<_OfferwallBankSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.banks
        : widget.banks
              .where(
                (b) => (b['name']?.toString().toLowerCase() ?? '').contains(
                  _query.toLowerCase(),
                ),
              )
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                'Select your bank',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search bank',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (_, i) {
                    final bank = filtered[i];
                    return ListTile(
                      title: Text(
                        bank['name']?.toString() ?? '',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => widget.onSelected(bank),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
