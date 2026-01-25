// lib/features/wallet/presentation/pages/wallet_screen.dart
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
  // local UI state: hide/show balance
  bool _hideBalance = false;

  @override
  void initState() {
    super.initState();
    // trigger load once displayed
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<WalletCubit>().loadAll(),
    );
  }

  Future<void> _onRefresh() => context.read<WalletCubit>().loadAll();

  // Bottom sheet with Transfer / Gift / Buy actions
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
                  // placeholder: gift flow
                  // showDialog(
                  //   context: context,
                  //   builder: (_) => AlertDialog(
                  //     title: const Text('Gift Coins'),
                  //     content: const Text('Gift flow goes here (placeholder).'),
                  //     actions: [
                  //       TextButton(
                  //         onPressed: () => Navigator.pop(context),
                  //         child: const Text('Close'),
                  //       ),
                  //     ],
                  //   ),
                  // );
                },
              ),
              const SizedBox(height: 10),
              _sheetTile(
                icon: Icons.shopping_cart,
                label: 'Buy Coins',
                subtitle: 'Open coin packages',
                onTap: () {
                  Navigator.pop(ctx);
                  HapticFeedback.selectionClick();
                  // navigate to buy coins screen already wired to WalletCubit
                  Navigator.pushNamed(context, RouteNames.buyCoins);
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
                icon: Icons.account_balance,
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
    // overall app gradient matching screenshot (dark blue -> near-black)
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
        // Show skeleton while loading or initial
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

        // If loading failed
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

        // Loaded state - render actual wallet
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
                    // top bar
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
                        // ACTIONS: show vertical menu (three dots)
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

                    // Balance card (replica: big balance + total earned inside same card)
                    _BalanceCard(
                      balance: loaded.balance,
                      earnedbalance: loaded.earnedBalance,
                      hideBalance: _hideBalance,
                      onToggleHide: () {
                        HapticFeedback.selectionClick();
                        setState(() => _hideBalance = !_hideBalance);
                      },
                    ),

                    const SizedBox(height: 20),

                    // Recent Activity header
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
                          onPressed: () {
                            // optional: navigate to full history
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text(' '),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Recent activity list (cards)
                    ...loaded.recent
                        .map((t) => _ActivityTile(transaction: t))
                        .toList(),

                    const SizedBox(height: 12),
                    // Spacer bottom
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

/// Balance card: exact layout replica (balance big, total earned small, action buttons)
class _BalanceCard extends StatelessWidget {
  final int balance;
  final double earnedbalance;
  final bool hideBalance;
  final VoidCallback onToggleHide;

  const _BalanceCard({
    Key? key,
    required this.balance,
    required this.earnedbalance,
    required this.hideBalance,
    required this.onToggleHide,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // card colors and style tuned to screenshot
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
          // header row: label + actions
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
                      // Eye icon replaces the previous monetization-trigger expectation
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
              // action icon (stylized) - leave monetization icon as decorative
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: const [
                    Icon(
                      Icons.monetization_on,
                      color: Color(0xFFFFD54F),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Total Earning (inside same card) - replicate the smaller panel inside
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                // left: small column
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
                        hideBalance ? '••••••' : formatusd(earnedbalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lifetime',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // right: balance actions
                Row(
                  children: [
                    // Buy button
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, RouteNames.buyCoins),
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

                    // const SizedBox(width: 10),
                    // // Gift / transfer fallback icon (tap to open same bottom sheet)
                    // InkWell(
                    //   onTap: () {
                    //     HapticFeedback.selectionClick();
                    //     // Open the same bottom sheet actions (transfer/gift)
                    //     // since this widget is stateless, we navigate up to find state
                    //     final state = context
                    //         .findAncestorStateOfType<_WalletScreenState>();
                    //     state?._showActionsSheet();
                    //   },
                    //   borderRadius: BorderRadius.circular(12),
                    //   child: Container(
                    //     padding: const EdgeInsets.all(10),
                    //     decoration: BoxDecoration(
                    //       color: Colors.white12,
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     child: const Icon(
                    //       Icons.card_giftcard,
                    //       color: Colors.white70,
                    //       size: 18,
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Each activity tile that matches screenshot style (rounded card, left icon, method, time, coin delta)
class _ActivityTile extends StatelessWidget {
  final TransactionModel transaction;
  const _ActivityTile({Key? key, required this.transaction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.coinsChange >= 0;
    final amountText = '${isCredit ? '+' : ''}${transaction.coinsChange}';
    final amountColor = isCredit ? Colors.greenAccent : Colors.redAccent;
    String formattedTXTType = transaction.type.replaceAll('_', ' ');

    // 2. Split into words, capitalize each
    formattedTXTType = formattedTXTType
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
    return Container(
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
              transaction.amountPaid > 0
                  ? Icons.shopping_bag
                  : Icons.swap_horiz,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedTXTType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat.yMMMd().add_jm().format(transaction.date),
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
                formatCoin(int.tryParse(amountText) as int),
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                transaction.amountPaid > 0
                    ? convertcointousd(transaction.coinsChange)
                    : '',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shimmer skeleton showing wireframe of the expected screen (balance card + list rows)
class _WalletShimmerSkeleton extends StatelessWidget {
  const _WalletShimmerSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.shade800;
    final highlight = Colors.grey.shade700;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Column(
        children: [
          // top skeleton card
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

/// Skeleton list rows
class _ShimmerList extends StatelessWidget {
  const _ShimmerList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.shade800;
    final highlight = Colors.grey.shade700;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
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
