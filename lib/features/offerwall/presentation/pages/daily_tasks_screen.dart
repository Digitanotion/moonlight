// lib/features/offerwall/presentation/pages/daily_tasks_screen.dart
//
// Locked (activation) state + unlocked Daily Tasks surface, per the client
// spec: "Activate your participation with one time 100 coins maintenance
// requirement to start earning cash daily for life. You will be able to
// withdraw your earnings every week."
//
// Migrated from Adjoe/Torox to Tapjoy/Timewall/CPX Research, all live now:
//  - Tapjoy: a WebView pointed at Tapjoy's hosted offerwall URL, keyed to
//    the signed-in user (see OfferwallController::postbackTapjoy).
//  - Timewall: NOT a WebView — their own docs say file uploads and other
//    features break in one, and recommend an external browser for more
//    revenue — so this tab is just a launch button (url_launcher) that
//    opens Timewall's tasks page outside the app (see
//    OfferwallController::postbackTimewall for the crediting side).
//  - CPX Research: a WebView, like Tapjoy, but the URL itself has to be
//    fetched from our own backend first (GET /offerwall/cpx/launch-url)
//    rather than built on-device — CPX's URL-signing secret is the same
//    one that verifies postbacks, so it can never ship inside the app
//    (see OfferwallService::buildCpxLaunchUrl on the API side).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/offerwall/data/datasources/offerwall_remote_data_source.dart';
import 'package:moonlight/features/offerwall/presentation/cubit/offerwall_cubit.dart';
import 'package:moonlight/features/post_view/presentation/widgets/user_helper.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  late final TabController _tabs = TabController(length: 3, vsync: this);

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
                    Tab(text: 'Tapjoy'),
                    Tab(text: 'Timewall'),
                    Tab(text: 'CPX'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: const [
                    _TapjoyOfferwallView(),
                    _TimewallOfferwallView(),
                    _CpxOfferwallView(),
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

/// Coins map 1:1 to USD cents everywhere in the offerwall system (the same
/// convention the Tapjoy/Timewall currency conversion rates were set up
/// with), so this is exact, not an approximation.
String _formatUsd(int coins) {
  final dollars = coins / 100;
  return dollars == dollars.roundToDouble()
      ? '\$${dollars.toStringAsFixed(0)}'
      : '\$${dollars.toStringAsFixed(2)}';
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
              '(${_formatUsd(costCoins)}) maintenance requirement to start '
              'earning cash daily for life. You will be able to withdraw '
              'your earnings every week.',
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
                        'Activate with $costCoins coins (${_formatUsd(costCoins)})',
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

/// Tapjoy's "Web Offerwall" — no native SDK, just their hosted offerwall
/// page loaded in a WebView and keyed to this user's id, exactly the same
/// integration shape as Adjoe/Torox before it. The SDK key here is the
/// public app identifier Tapjoy's own docs embed directly in client URLs —
/// not a secret (the actual secret, used to verify their reward callback,
/// lives only in the API's config/offerwall.php, never shipped client-side).
class _TapjoyOfferwallView extends StatefulWidget {
  const _TapjoyOfferwallView();

  @override
  State<_TapjoyOfferwallView> createState() => _TapjoyOfferwallViewState();
}

class _TapjoyOfferwallViewState extends State<_TapjoyOfferwallView> {
  static const _sdkKey =
      'uTb0F02XRG-oTHvyG8qcOAECwSM7fI4LAVJIA1iVA8wHSKARWEeBzcm817rH';

  WebViewController? _controller;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final userId = UserHelper.getCurrentUser(context)?.id ?? '';
    if (userId.isEmpty) {
      // Shouldn't happen — this screen already requires being signed in —
      // but never point Tapjoy at an empty/unidentifiable user.
      _hasError = true;
      return;
    }

    final url =
        'https://rewards.unity.com/owp/web/link/$_sdkKey/u/${Uri.encodeComponent(userId)}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.dark)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _loading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (err) {
            if (err.isForMainFrame ?? true) {
              setState(() {
                _loading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  void _retry() {
    final userId = UserHelper.getCurrentUser(context)?.id ?? '';
    if (userId.isEmpty || _controller == null) return;
    setState(() => _hasError = false);
    _controller!.reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _controller == null) {
      // Couldn't even build a URL (no signed-in user id) — nothing to retry.
      return const _OfferwallErrorView(
        message: "Couldn't load Tapjoy tasks. Please try again shortly.",
        onRetry: null,
      );
    }

    return Stack(
      children: [
        if (!_hasError && _controller != null)
          Positioned.fill(child: WebViewWidget(controller: _controller!)),
        if (_hasError)
          _OfferwallErrorView(
            message: 'Could not load Tapjoy tasks.',
            onRetry: _retry,
          ),
        if (_loading && !_hasError)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF1FBF75)),
          ),
      ],
    );
  }
}

class _OfferwallErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _OfferwallErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Color(0xFF1FBF75)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// CPX Research's offerwall, like Tapjoy, is fine to embed in a WebView —
/// but unlike Tapjoy's SDK key, the signed launch URL can't be built on
/// this device: it's signed with the same secret that verifies postbacks,
/// so it's fetched from our backend (which keeps that secret server-side)
/// instead.
class _CpxOfferwallView extends StatefulWidget {
  const _CpxOfferwallView();

  @override
  State<_CpxOfferwallView> createState() => _CpxOfferwallViewState();
}

class _CpxOfferwallViewState extends State<_CpxOfferwallView> {
  WebViewController? _controller;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    String url;
    try {
      url = await sl<OfferwallRemoteDataSource>().getCpxLaunchUrl();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
      return;
    }
    if (!mounted) return;

    setState(() {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(AppColors.dark)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() {
              _loading = true;
              _hasError = false;
            }),
            onPageFinished: (_) => setState(() => _loading = false),
            onWebResourceError: (err) {
              if (err.isForMainFrame ?? true) {
                setState(() {
                  _loading = false;
                  _hasError = true;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(url));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (!_hasError && _controller != null)
          Positioned.fill(child: WebViewWidget(controller: _controller!)),
        if (_hasError)
          _OfferwallErrorView(
            message: 'Could not load CPX Research tasks.',
            onRetry: _load,
          ),
        if (_loading && !_hasError)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF1FBF75)),
          ),
      ],
    );
  }
}

/// Timewall explicitly recommends AGAINST embedding their offerwall in a
/// WebView (their own dashboard: "loading the URL in web view will cause
/// many features to break... you will earn a lot more revenue by opening
/// in an external browser" — the file-upload control some tasks need
/// specifically doesn't work in a WebView). So unlike Tapjoy, this tab is
/// just a launcher — a button that opens Timewall's hosted tasks page in
/// the device's own browser via url_launcher.
class _TimewallOfferwallView extends StatelessWidget {
  const _TimewallOfferwallView();

  static const _placementId = '70b2a2de34c50797';

  Future<void> _openTimewall(BuildContext context) async {
    final userId = UserHelper.getCurrentUser(context)?.id ?? '';
    if (userId.isEmpty) return;

    final uri = Uri.parse(
      'https://timewall.io/users/login'
      '?oid=$_placementId'
      '&uid=${Uri.encodeComponent(userId)}'
      '&tab=tasks',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        TopSnack.error(context, "Couldn't open Timewall. Please try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.open_in_browser_rounded,
              color: const Color(0xFF1FBF75).withValues(alpha: 0.8),
              size: 40,
            ),
            const SizedBox(height: 16),
            const Text(
              'Timewall tasks open in your browser',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Surveys and tasks work best outside the app — tap below to '
              'open Timewall, complete tasks, then come back here. Your '
              'earnings sync automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1FBF75),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _openTimewall(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text(
                  'Open Timewall Tasks',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
