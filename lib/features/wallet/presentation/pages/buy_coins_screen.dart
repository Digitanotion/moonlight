// lib/features/wallet/presentation/pages/buy_coins_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/features/wallet/services/play_billing_service.dart';
import '../../domain/models/coin_package.dart';
import '../cubit/wallet_cubit.dart';
import '../widgets/custom_spinner.dart';
import 'package:shimmer/shimmer.dart';

class BuyCoinsScreen extends StatefulWidget {
  static const routeName = RouteNames.buyCoins;
  const BuyCoinsScreen({Key? key}) : super(key: key);

  @override
  State<BuyCoinsScreen> createState() => _BuyCoinsScreenState();
}

class _BuyCoinsScreenState extends State<BuyCoinsScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletCubit>().loadAll();
    });
  }

  Future<void> _onRefresh() async => context.read<WalletCubit>().loadAll();

  @override
  Widget build(BuildContext context) {
    const gradientBg = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF071032), Color(0xFF040407)],
    );

    return BlocConsumer<WalletCubit, WalletState>(
      listener: (context, state) {
        if (state is WalletError) {
          debugPrint(state.message);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final loading =
            state is WalletLoading ||
            (state is WalletLoaded && state.packages.isEmpty);

        if (loading) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: const BoxDecoration(gradient: gradientBg),
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
              decoration: const BoxDecoration(gradient: gradientBg),
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
                          'Unable to load coin packages',
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

        final packages = (state is WalletLoaded)
            ? state.packages
            : <CoinPackage>[];

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(gradient: gradientBg),
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
                          'Buy Coins',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(flex: 2),
                        Opacity(
                          opacity: 0.0,
                          child: Icon(
                            Icons.settings,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Coin Packages
                    ...packages.map(
                      (pkg) => _CoinPackageCard(
                        pkg: pkg,
                        onBuy: () => _onBuyPressed(pkg),
                      ),
                    ),

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

  Future<void> _onBuyPressed(CoinPackage pkg) async {
    // Confirm dialog (unchanged)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Purchase'),
        content: Text(
          // Use priceUsdCents if your model uses cents; adapt if you use priceUSD
          'Buy ${formatCoin(pkg.coins)} coins for ${convertcointousd(pkg.priceUsdCents ?? pkg.priceUSD)}?',
        ),
        backgroundColor: AppColors.bluePrimary,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buy'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isProcessing = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CustomSpinner()),
    );

    try {
      // If productId exists, use PlayBillingService (recommended path)
      final sl = GetIt.instance;
      final playAvailable =
          sl.isRegistered<PlayBillingService>() &&
          pkg.productId != null &&
          pkg.productId.isNotEmpty;

      if (playAvailable) {
        final play = sl<PlayBillingService>();
        // End-to-end: Play Billing -> server verify -> ack -> returns TransactionModel
        final txn = await play.buyAndComplete(
          productId: pkg.productId!,
          packageCode: pkg.id,
        );

        if (!mounted) return;
        Navigator.pop(context); // remove spinner
        setState(() => _isProcessing = false);

        if (txn != null) {
          Navigator.pushNamed(
            context,
            RouteNames.transactionReceipt,
            arguments: txn,
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Purchase failed')));
        }
      } else {
        // Fallback: older server-side / local flow (keeps app usable during staged rollout)
        final txn = await context.read<WalletCubit>().buyPackage(pkg.id);
        if (!mounted) return;
        Navigator.pop(context);
        setState(() => _isProcessing = false);

        if (txn != null) {
          Navigator.pushNamed(
            context,
            RouteNames.transactionReceipt,
            arguments: txn,
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Purchase failed')));
        }
      }
    } catch (e) {
      // Ensure spinner closed
      if (mounted) Navigator.pop(context);
      setState(() => _isProcessing = false);

      // Present friendly message
      final message = (e is Exception) ? e.toString() : 'Purchase error';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Purchase error: $message')));
      }
    }
  }
}

/// Coin package card styled to match wallet theme
class _CoinPackageCard extends StatelessWidget {
  final CoinPackage pkg;
  final VoidCallback onBuy;
  const _CoinPackageCard({Key? key, required this.pkg, required this.onBuy})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white10,
            child: const Icon(
              Icons.monetization_on,
              color: Color(0xFFFFD54F),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pkg.coins} Coins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  convertcointousd(pkg.priceUSD),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onBuy,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Buy',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer skeleton for Buy Coins
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
