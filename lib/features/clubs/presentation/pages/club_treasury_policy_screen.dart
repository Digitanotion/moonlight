// lib/features/clubs/presentation/pages/club_treasury_policy_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/data/datasources/club_treasury_remote_data_source.dart';
import 'package:moonlight/features/clubs/domain/entities/club_treasury.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_treasury_cubit.dart';
import 'package:moonlight/widgets/top_snack.dart';

class ClubTreasuryPolicyScreen extends StatefulWidget {
  final String clubUuid;
  final ClubTreasuryPolicy? policy;

  const ClubTreasuryPolicyScreen({
    super.key,
    required this.clubUuid,
    this.policy,
  });

  @override
  State<ClubTreasuryPolicyScreen> createState() =>
      _ClubTreasuryPolicyScreenState();
}

class _ClubTreasuryPolicyScreenState extends State<ClubTreasuryPolicyScreen> {
  late String _quorum;
  late double _minAmountUsd;
  late int _cooldownDays;
  late int _expiryHours;

  @override
  void initState() {
    super.initState();
    final p = widget.policy;
    _quorum = p?.quorum ?? 'any';
    _minAmountUsd = p?.minAmountUsd ?? 10;
    _cooldownDays = p?.cooldownDays ?? 0;
    _expiryHours = p?.expiryHours ?? 72;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ClubTreasuryCubit(
        ctx.read<ClubTreasuryRemoteDataSource>(),
        widget.clubUuid,
      ),
      child: BlocConsumer<ClubTreasuryCubit, ClubTreasuryState>(
        listener: (context, state) {
          if (state.error != null) {
            TopSnack.error(context, state.error!);
            context.read<ClubTreasuryCubit>().clearMessages();
          }
          if (state.success != null) {
            TopSnack.success(context, state.success!);
            context.read<ClubTreasuryCubit>().clearMessages();
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
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
                    _buildTopBar(context),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // ── Quorum ──────────────────────────────────────────
                          _PolicySection(
                            icon: Icons.how_to_vote_rounded,
                            color: Colors.purpleAccent,
                            title: 'Approval Quorum',
                            subtitle:
                                'How many admins must approve before a withdrawal executes?',
                          ),
                          const SizedBox(height: 12),
                          _QuorumSelector(
                            value: _quorum,
                            onChanged: (v) => setState(() => _quorum = v),
                          ),
                          const SizedBox(height: 28),

                          // ── Minimum amount ──────────────────────────────────
                          _PolicySection(
                            icon: Icons.attach_money_rounded,
                            color: Colors.greenAccent,
                            title: 'Minimum Withdrawal',
                            subtitle:
                                'The smallest amount that can be requested.',
                          ),
                          const SizedBox(height: 12),
                          _SliderField(
                            value: _minAmountUsd,
                            min: 1,
                            max: 500,
                            divisions: 499,
                            label: '\$${_minAmountUsd.toStringAsFixed(0)}',
                            onChanged: (v) => setState(() => _minAmountUsd = v),
                          ),
                          const SizedBox(height: 28),

                          // ── Cooldown ────────────────────────────────────────
                          _PolicySection(
                            icon: Icons.timer_outlined,
                            color: Colors.orange,
                            title: 'Withdrawal Cooldown',
                            subtitle:
                                'Minimum days between two approved withdrawals. 0 = no limit.',
                          ),
                          const SizedBox(height: 12),
                          _StepperField(
                            value: _cooldownDays,
                            min: 0,
                            max: 90,
                            label: _cooldownDays == 0
                                ? 'No cooldown'
                                : '$_cooldownDays day${_cooldownDays == 1 ? '' : 's'}',
                            onChanged: (v) => setState(() => _cooldownDays = v),
                          ),
                          const SizedBox(height: 28),

                          // ── Expiry ──────────────────────────────────────────
                          _PolicySection(
                            icon: Icons.hourglass_empty_rounded,
                            color: Colors.blueAccent,
                            title: 'Request Expiry',
                            subtitle:
                                'Auto-cancel pending requests after this many hours. 0 = never expires.',
                          ),
                          const SizedBox(height: 12),
                          _StepperField(
                            value: _expiryHours,
                            min: 0,
                            max: 168,
                            step: 24,
                            label: _expiryHours == 0
                                ? 'Never expires'
                                : '$_expiryHours hour${_expiryHours == 1 ? '' : 's'}',
                            onChanged: (v) => setState(() => _expiryHours = v),
                          ),
                          const SizedBox(height: 32),

                          // ── Preview card ─────────────────────────────────────
                          _PolicyPreviewCard(
                            quorum: _quorum,
                            minAmountUsd: _minAmountUsd,
                            cooldownDays: _cooldownDays,
                            expiryHours: _expiryHours,
                          ),
                          const SizedBox(height: 32),

                          // ── Save ─────────────────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: state.submitting
                                  ? null
                                  : () => _save(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7A00),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: state.submitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save Policy',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _save(BuildContext context) {
    context.read<ClubTreasuryCubit>().updatePolicy({
      'quorum': _quorum,
      'min_amount_usd': _minAmountUsd,
      'cooldown_days': _cooldownDays,
      'expiry_hours': _expiryHours,
    });
  }

  Widget _buildTopBar(BuildContext context) {
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
          const Text(
            'Withdrawal Policy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quorum Selector ───────────────────────────────────────────────────────────

class _QuorumSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _QuorumSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [
      (
        value: 'any',
        label: 'Any Admin',
        sub: '1 approval needed',
        icon: Icons.person_rounded,
      ),
      (
        value: 'majority',
        label: 'Majority',
        sub: '⌈n/2⌉ admins must approve',
        icon: Icons.people_rounded,
      ),
      (
        value: 'all',
        label: 'All Admins',
        sub: 'Every admin must approve',
        icon: Icons.group_rounded,
      ),
    ];

    return Column(
      children: options
          .map(
            (o) => _QuorumOption(
              label: o.label,
              subtitle: o.sub,
              icon: o.icon,
              selected: value == o.value,
              onTap: () => onChanged(o.value),
            ),
          )
          .toList(),
    );
  }
}

class _QuorumOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _QuorumOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? Colors.purpleAccent.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.purpleAccent
                : Colors.white.withOpacity(0.1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.purpleAccent : Colors.white38,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.purpleAccent,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Slider field ──────────────────────────────────────────────────────────────

class _SliderField extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;
  const _SliderField({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Amount',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.greenAccent,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.greenAccent,
              overlayColor: Colors.greenAccent.withOpacity(0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${min.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                '\$${max.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stepper field ─────────────────────────────────────────────────────────────

class _StepperField extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final int step;
  final String label;
  final ValueChanged<int> onChanged;
  const _StepperField({
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: value > min
                ? () => onChanged((value - step).clamp(min, max))
                : null,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: value > min
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.remove_rounded,
                color: value > min ? Colors.white : Colors.white24,
                size: 18,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: value < max
                ? () => onChanged((value + step).clamp(min, max))
                : null,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: value < max
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add_rounded,
                color: value < max ? Colors.white : Colors.white24,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Policy section header ─────────────────────────────────────────────────────

class _PolicySection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _PolicySection({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Preview card ──────────────────────────────────────────────────────────────

class _PolicyPreviewCard extends StatelessWidget {
  final String quorum;
  final double minAmountUsd;
  final int cooldownDays;
  final int expiryHours;

  const _PolicyPreviewCard({
    required this.quorum,
    required this.minAmountUsd,
    required this.cooldownDays,
    required this.expiryHours,
  });

  @override
  Widget build(BuildContext context) {
    final quorumLabel = switch (quorum) {
      'all' => 'All admins must approve',
      'majority' => 'Majority must approve',
      _ => 'Any 1 admin approves',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Policy Summary',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          _PreviewRow(icon: Icons.how_to_vote_rounded, label: quorumLabel),
          _PreviewRow(
            icon: Icons.attach_money_rounded,
            label: 'Min \$${minAmountUsd.toStringAsFixed(0)} per request',
          ),
          _PreviewRow(
            icon: Icons.timer_outlined,
            label: cooldownDays == 0
                ? 'No cooldown between withdrawals'
                : '$cooldownDays-day cooldown',
          ),
          _PreviewRow(
            icon: Icons.hourglass_empty_rounded,
            label: expiryHours == 0
                ? 'Requests never expire'
                : 'Requests expire after ${expiryHours}h',
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PreviewRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
