// lib/features/wallet/presentation/pages/wallet_screen.dart
//
// Changes vs previous version:
//   1. _ActivityTile is now tappable → navigates to transactionDetail
//   2. _onBuyCoins() uses .then() to refresh WalletCubit after returning
//   3. All other pushNamed calls for buy-coins use the same pattern
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../domain/models/transaction_model.dart';
import '../cubit/wallet_cubit.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/utils/formatting.dart';

class WalletScreen extends StatefulWidget {
  static const routeName = RouteNames.wallet;
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _hideBalance = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<WalletCubit>().loadAll(),
    );
  }

  Future<void> _onRefresh() => context.read<WalletCubit>().loadAll();

  // ── Navigate to Buy Coins and refresh wallet when user returns ──────────────
  void _goToBuyCoins() {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, RouteNames.buyCoins).then((_) {
      if (mounted) context.read<WalletCubit>().loadAll();
    });
  }

  void _showActionsSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0F24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _sheetTile(
                icon: Icons.card_giftcard,
                label: 'Transfer Coins',
                subtitle: 'Send coins to other users',
                onTap: () {
                  Navigator.pop(ctx);
                  HapticFeedback.selectionClick();
                  Navigator.pushNamed(context, RouteNames.giftCoins);
                },
              ),
              const SizedBox(height: 10),
              _sheetTile(
                icon: Icons.shopping_cart,
                label: 'Buy Coins',
                subtitle: 'Open coin packages',
                onTap: () {
                  Navigator.pop(ctx);
                  _goToBuyCoins();
                },
              ),
              const SizedBox(height: 10),
              _sheetTile(
                icon: Icons.account_balance,
                label: 'Request Withdrawal',
                subtitle: 'Withdraw your earnings',
                onTap: () {
                  Navigator.pop(ctx);
                  HapticFeedback.selectionClick();
                  Navigator.pushNamed(context, RouteNames.withdrawal);
                },
              ),
              const SizedBox(height: 10),
              _sheetTile(
                icon: Icons.lock_outline,
                label: 'Set Wallet PIN',
                subtitle: 'Protect your wallet with a PIN',
                onTap: () {
                  Navigator.pop(ctx);
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pushNamed(RouteNames.setNewPin);
                },
              ),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(icon, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const screenGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF071032), Color(0xFF040407)],
    );

    return BlocConsumer<WalletCubit, WalletState>(
      listener: (context, state) {
        if (state is WalletError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        if (state is WalletLoading || state is WalletInitial) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: const BoxDecoration(gradient: screenGradient),
              child: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: const Color(0xFFFF7A00),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      SizedBox(height: 8),
                      _WalletShimmerSkeleton(),
                      SizedBox(height: 20),
                      _ShimmerList(),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (state is WalletError) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: const BoxDecoration(gradient: screenGradient),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Unable to load wallet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.message,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
                              context.read<WalletCubit>().loadAll(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final loaded = state as WalletLoaded;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(gradient: screenGradient),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: const Color(0xFFFF7A00),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  children: [
                    // Top bar
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.maybePop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'My Wallet',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(flex: 2),
                        InkWell(
                          onTap: _showActionsSheet,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _BalanceCard(
                      balance: loaded.balance,
                      earnedbalance: loaded.earnedBalance,
                      hideBalance: _hideBalance,
                      onToggleHide: () {
                        HapticFeedback.selectionClick();
                        setState(() => _hideBalance = !_hideBalance);
                      },
                      onBuyCoins: _goToBuyCoins,
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Activity',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text(' '),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ...loaded.recent
                        .map((t) => _ActivityTile(transaction: t))
                        .toList(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── balance card ─────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final int balance;
  final int earnedbalance;
  final bool hideBalance;
  final VoidCallback onToggleHide;
  final VoidCallback onBuyCoins;

  const _BalanceCard({
    Key? key,
    required this.balance,
    required this.earnedbalance,
    required this.hideBalance,
    required this.onToggleHide,
    required this.onBuyCoins,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1B47), Color(0xFF24114C)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        hideBalance ? '••••••' : formatCoin(balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Coins',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onToggleHide,
                        child: Icon(
                          hideBalance ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    hideBalance
                        ? '••••••'
                        : '~ \$${(balance * 0.005).toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFFFD54F),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Earned',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hideBalance ? '••••••' : formatCoin(earnedbalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bonuses',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: onBuyCoins,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Buy',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── activity tile ────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final TransactionModel transaction;
  const _ActivityTile({Key? key, required this.transaction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final txn = transaction;
    final isCredit = txn.coinsChange >= 0;
    final amountText = '${isCredit ? '+' : ''}${txn.coinsChange}';
    final amountColor = isCredit ? Colors.greenAccent : Colors.redAccent;

    String formattedType = txn.type.replaceAll('_', ' ');
    formattedType = formattedType
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? ''
              : w[0].toUpperCase() + w.substring(1).toLowerCase(),
        )
        .join(' ');

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pushNamed(
          context,
          RouteNames.transactionDetail,
          arguments: txn,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white10,
              child: Icon(
                txn.amountPaid > 0 ? Icons.shopping_bag : Icons.swap_horiz,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat.yMMMd().add_jm().format(txn.date),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  txn.amountPaid > 0 ? formatusd(txn.amountPaid) : '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── shimmer ──────────────────────────────────────────────────────────────────

class _WalletShimmerSkeleton extends StatelessWidget {
  const _WalletShimmerSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 18, width: 120, color: Colors.white),
                const SizedBox(height: 12),
                Container(height: 36, width: 180, color: Colors.white),
                const SizedBox(height: 14),
                Container(
                  height: 64,
                  width: double.infinity,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      child: Column(
        children: List.generate(4, (i) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(height: 10, width: 140, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Container(height: 14, width: 60, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 50, color: Colors.white),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
