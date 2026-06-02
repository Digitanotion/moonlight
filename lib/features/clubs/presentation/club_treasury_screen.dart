// lib/features/clubs/presentation/pages/club_treasury_screen.dart
//
// KEY FIXES in this version:
//  1. PIN setup banner shows at top whenever treasury_ready == false,
//     regardless of isOwner (all admins see it, but only owner can tap it)
//  2. Settings tab always shows PIN tile for the owner — moved OUT of
//     the isOwner guard so it's the FIRST item always
//  3. FAB logic fixed: shows "Setup PIN" to owner if not ready,
//     shows "Request Withdrawal" to any admin if ready
//  4. Debug: logs what isOwner/isAdmin values are received

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/features/clubs/domain/entities/club_treasury.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_treasury_cubit.dart';
import 'package:moonlight/features/clubs/data/datasources/club_treasury_remote_data_source.dart';
import 'package:moonlight/widgets/top_snack.dart';

class ClubTreasuryScreen extends StatefulWidget {
  final String clubUuid;
  final String clubName;
  final bool isOwner;
  final bool isAdmin;

  const ClubTreasuryScreen({
    super.key,
    required this.clubUuid,
    required this.clubName,
    required this.isOwner,
    this.isAdmin = false,
  });

  @override
  State<ClubTreasuryScreen> createState() => _ClubTreasuryScreenState();
}

class _ClubTreasuryScreenState extends State<ClubTreasuryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Effective admin = owner OR explicitly passed isAdmin
  bool get _effectiveIsAdmin => widget.isOwner || widget.isAdmin;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ClubTreasuryCubit(
        ctx.read<ClubTreasuryRemoteDataSource>(),
        widget.clubUuid,
      )..load(),
      child: BlocConsumer<ClubTreasuryCubit, ClubTreasuryState>(
        listener: (context, state) {
          if (state.error != null) {
            TopSnack.error(context, state.error!);
            context.read<ClubTreasuryCubit>().clearMessages();
          }
          if (state.success != null) {
            TopSnack.success(context, state.success!);
            context.read<ClubTreasuryCubit>().clearMessages();
          }
        },
        builder: (context, state) {
          final treasuryReady = state.summary?.treasuryReady ?? false;

          return Scaffold(
            backgroundColor: AppColors.bgBottom,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.bgTop, AppColors.bgBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, state),

                    if (state.loading && state.summary == null)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      )
                    else ...[
                      // ── PIN not set warning (all admins see, only owner acts) ──
                      if (!treasuryReady)
                        _PinNotSetBanner(
                          clubUuid: widget.clubUuid,
                          isOwner:
                              state.summary?.isOwner ??
                              false, // ← was widget.isOwner
                        ),

                      // ── Balance card ──────────────────────────────────────
                      if (state.summary != null)
                        _BalanceCard(summary: state.summary!),

                      // ── Tabs ──────────────────────────────────────────────
                      _buildTabBar(),

                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _RequestsTab(
                              requests: state.requests,
                              clubUuid: widget.clubUuid,
                              clubName: widget.clubName,
                            ),
                            _HistoryTab(
                              requests: state.requests,
                              clubUuid: widget.clubUuid,
                              clubName: widget.clubName,
                            ),
                            _SettingsTab(
                              clubUuid: widget.clubUuid,
                              summary: state.summary,
                              isOwner:
                                  state.summary?.isOwner ??
                                  false, // ← was widget.isOwner fallback
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── FAB ───────────────────────────────────────────────────────
            floatingActionButton: _buildFab(context, state),
          );
        },
      ),
    );
  }

  Widget? _buildFab(BuildContext context, ClubTreasuryState state) {
    final isOwner = state.summary?.isOwner ?? false;
    final isAdmin = state.summary?.isAdmin ?? false;
    final treasuryReady = state.summary?.treasuryReady ?? false;

    if (!treasuryReady && isOwner) {
      return FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        onPressed: () => _goToSetup(context),
        icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
        label: const Text(
          'Setup Treasury PIN',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      );
    }

    if (treasuryReady && isAdmin) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF7A00),
        onPressed: () => _openWithdrawalRequest(context),
        icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
        label: const Text(
          'Request Withdrawal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      );
    }

    return null;
  }

  Widget _buildTopBar(BuildContext context, ClubTreasuryState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Club Treasury',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.clubName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Audit log shortcut
          IconButton(
            tooltip: 'Audit Log',
            icon: const Icon(Icons.receipt_long_rounded, color: Colors.white54),
            onPressed: () => Navigator.pushNamed(
              context,
              RouteNames.clubTreasuryAuditLog,
              arguments: {'clubUuid': widget.clubUuid},
            ),
          ),
          if (state.loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              onPressed: () => context.read<ClubTreasuryCubit>().load(),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabs,
        // indicatorPadding: const EdgeInsets.symmetric(horizontal: 50),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: const Color(0xFFFF7A00),
          borderRadius: BorderRadius.circular(10),
        ),

        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            text: 'Pending',
            iconMargin: EdgeInsets.only(left: 10, right: 10),
          ),
          Tab(text: 'History'),
          Tab(text: 'Settings'),
        ],
      ),
    );
  }

  void _goToSetup(BuildContext context) {
    Navigator.pushNamed(
      context,
      RouteNames.clubTreasurySetup,
      arguments: {'clubUuid': widget.clubUuid, 'pinOnly': false},
    ).then((_) => context.read<ClubTreasuryCubit>().load());
  }

  void _openWithdrawalRequest(BuildContext context) {
    final summary = context.read<ClubTreasuryCubit>().state.summary;
    if (summary == null) return;

    if (summary.hasCooldown) {
      final dt = summary.cooldownEndsAt;
      final label = dt != null ? '${dt.day}/${dt.month}/${dt.year}' : 'soon';
      TopSnack.error(
        context,
        'Cooldown active. Next withdrawal available $label.',
      );
      return;
    }

    Navigator.pushNamed(
      context,
      RouteNames.clubWithdrawalRequest,
      arguments: {
        'clubUuid': widget.clubUuid,
        'clubName': widget.clubName,
        'summary': summary,
      },
    ).then((_) => context.read<ClubTreasuryCubit>().load());
  }
}

// ── PIN Not Set Banner ────────────────────────────────────────────────────────
// Shown to ALL admins when treasury PIN hasn't been configured yet.
// Only the owner can tap through to set it.

class _PinNotSetBanner extends StatelessWidget {
  final String clubUuid;
  final bool isOwner;
  const _PinNotSetBanner({required this.clubUuid, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isOwner
          ? () => Navigator.pushNamed(
              context,
              RouteNames.clubTreasurySetup,
              arguments: {'clubUuid': clubUuid, 'pinOnly': false},
            ).then((_) => context.read<ClubTreasuryCubit>().load())
          : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Treasury PIN not set',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    isOwner
                        ? 'Tap to create a 6-digit PIN and enable withdrawals'
                        : 'Ask the club owner to set up the treasury PIN',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isOwner)
              const Icon(Icons.chevron_right_rounded, color: Colors.orange),
          ],
        ),
      ),
    );
  }
}

// ── Balance Card ──────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final ClubTreasurySummary summary;
  const _BalanceCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF2D1B69)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFFFF7A00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Club Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (summary.hasCooldown)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_rounded, color: Colors.orange, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Cooldown',
                        style: TextStyle(color: Colors.orange, fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Main balance
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${summary.usdAvailable.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${formatCoin(summary.coinsAvailable)} coins',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          // Reserved coins
          if (summary.coinsReserved > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${formatCoin(summary.coinsReserved)} coins reserved (pending)',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _StatChip(
                label: 'Total Earned',
                value: '\$${summary.usdTotalEarned.toStringAsFixed(0)}',
                color: Colors.greenAccent,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Withdrawn',
                value: '\$${summary.usdTotalWithdrawn.toStringAsFixed(0)}',
                color: Colors.white54,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Requests Tab ──────────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  final List<ClubWithdrawalRequest> requests;
  final String clubUuid;
  final String clubName;
  const _RequestsTab({
    required this.requests,
    required this.clubUuid,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context) {
    final pending = requests
        .where((r) => r.isPending || r.isProcessing)
        .toList();

    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white.withOpacity(0.25),
              size: 56,
            ),
            const SizedBox(height: 14),
            const Text(
              'No pending requests',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Tap "Request Withdrawal" below to start a new request.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: () => context.read<ClubTreasuryCubit>().load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: pending.length,
        itemBuilder: (_, i) => _RequestCard(
          request: pending[i],
          clubUuid: clubUuid,
          clubName: clubName,
        ),
      ),
    );
  }
}

// ── History Tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final List<ClubWithdrawalRequest> requests;
  final String clubUuid;
  final String clubName;
  const _HistoryTab({
    required this.requests,
    required this.clubUuid,
    required this.clubName,
  });

  @override
  Widget build(BuildContext context) {
    final history = requests.where((r) => r.isTerminal).toList();

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              color: Colors.white.withOpacity(0.25),
              size: 56,
            ),
            const SizedBox(height: 14),
            const Text(
              'No withdrawal history yet',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: history.length,
      itemBuilder: (_, i) => _RequestCard(
        request: history[i],
        clubUuid: clubUuid,
        clubName: clubName,
        compact: true,
      ),
    );
  }
}

// ── Settings Tab ──────────────────────────────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  final String clubUuid;
  final ClubTreasurySummary? summary;
  final bool isOwner;
  const _SettingsTab({
    required this.clubUuid,
    required this.summary,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ── PIN setup — owner only, always first ──────────────────────
        if (isOwner) ...[
          _SettingsTile(
            icon: Icons.lock_rounded,
            title: 'Treasury PIN',
            subtitle: summary?.treasuryReady == true
                ? 'PIN is set — tap to change'
                : '⚠️  Not set — tap to configure now',
            color: summary?.treasuryReady == true
                ? Colors.greenAccent
                : Colors.orange,
            badge: summary?.treasuryReady == true ? null : '!',
            onTap: () => Navigator.pushNamed(
              context,
              RouteNames.clubTreasurySetup,
              arguments: {'clubUuid': clubUuid, 'pinOnly': true},
            ).then((_) => context.read<ClubTreasuryCubit>().load()),
          ),
          // const SizedBox(height: 12),

          // _SettingsTile(
          //   icon: Icons.account_balance_rounded,
          //   title: 'Default Payout Account',
          //   subtitle: 'Set a default bank or PayPal for withdrawals',
          //   color: Colors.blueAccent,
          //   onTap: () => Navigator.pushNamed(
          //     context,
          //     RouteNames.clubTreasuryPayoutProfile,
          //     arguments: {'clubUuid': clubUuid},
          //   ).then((_) => context.read<ClubTreasuryCubit>().load()),
          // ),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.tune_rounded,
            title: 'Withdrawal Policy',
            subtitle: _policyLabel(summary?.policy),
            color: Colors.purpleAccent,
            onTap: () => Navigator.pushNamed(
              context,
              RouteNames.clubTreasuryPolicy,
              arguments: {'clubUuid': clubUuid, 'policy': summary?.policy},
            ).then((_) => context.read<ClubTreasuryCubit>().load()),
          ),
          const SizedBox(height: 12),
        ],

        // ── Audit log — all admins ────────────────────────────────────
        _SettingsTile(
          icon: Icons.receipt_long_rounded,
          title: 'Audit Log',
          subtitle: 'Immutable record of all treasury actions',
          color: Colors.tealAccent,
          onTap: () => Navigator.pushNamed(
            context,
            RouteNames.clubTreasuryAuditLog,
            arguments: {'clubUuid': clubUuid},
          ),
        ),

        // Note for non-owners
        if (!isOwner) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PIN and policy settings are managed by the club owner.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _policyLabel(ClubTreasuryPolicy? p) {
    if (p == null) return 'Default — any admin approves';
    final q = switch (p.quorum) {
      'all' => 'All admins must approve',
      'majority' => 'Majority must approve',
      _ => 'Any admin approves',
    };
    return '$q · Min \$${p.minAmountUsd.toStringAsFixed(0)}';
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badge != null
                ? color.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.bgBottom,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: badge != null
                          ? Colors.orange.withOpacity(0.9)
                          : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final ClubWithdrawalRequest request;
  final String clubUuid;
  final String clubName;
  final bool compact;
  const _RequestCard({
    required this.request,
    required this.clubUuid,
    required this.clubName,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        RouteNames.clubWithdrawalDetail,
        arguments: {
          'clubUuid': clubUuid,
          'requestUuid': request.uuid,
          'clubName':
              clubName, // ← already there if you followed earlier patches
        },
      ).then((_) => context.read<ClubTreasuryCubit>().load()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _statusColor(request.status).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: request.requester?.avatarUrl != null
                      ? NetworkImage(request.requester!.avatarUrl!)
                      : null,
                  backgroundColor: Colors.white12,
                  child: request.requester?.avatarUrl == null
                      ? const Icon(
                          Icons.person,
                          color: Colors.white54,
                          size: 18,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.requester?.fullname ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _timeAgo(request.createdAt),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: request.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${request.amountUsd.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFFF7A00),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${formatCoin(request.amountCoins)} coins',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              request.reason,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!compact && request.isPending) ...[
              const SizedBox(height: 12),
              _QuorumBar(request: request),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'pending_approval' => Colors.orange,
    'processing' || 'approved' => Colors.blue,
    'completed' => Colors.green,
    'failed' || 'rejected' => Colors.red,
    _ => Colors.grey,
  };

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'pending_approval' => (Colors.orange, 'Pending'),
      'approved' => (Colors.blue, 'Approved'),
      'processing' => (Colors.blue, 'Processing'),
      'completed' => (Colors.green, 'Completed'),
      'failed' => (Colors.red, 'Failed'),
      'rejected' => (Colors.red, 'Rejected'),
      'cancelled' => (Colors.grey, 'Cancelled'),
      'expired' => (Colors.grey, 'Expired'),
      _ => (Colors.grey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuorumBar extends StatelessWidget {
  final ClubWithdrawalRequest request;
  const _QuorumBar({required this.request});

  @override
  Widget build(BuildContext context) {
    final progress = request.approvalsRequired == 0
        ? 1.0
        : (request.approvalsReceived / request.approvalsRequired).clamp(
            0.0,
            1.0,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${request.approvalsReceived}/${request.approvalsRequired} approvals',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (request.canApprove)
              const Text(
                'Tap to approve',
                style: TextStyle(
                  color: Color(0xFFFF7A00),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(
              request.quorumReached ? Colors.green : const Color(0xFFFF7A00),
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
