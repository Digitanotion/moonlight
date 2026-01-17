import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/domain/repositories/club_income_repository.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_income_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_income_state.dart';
import 'package:moonlight/features/clubs/domain/entities/club_transaction.dart';
import 'package:share_plus/share_plus.dart';

class ClubIncomeDetailsScreen extends StatelessWidget {
  final String clubUuid;

  const ClubIncomeDetailsScreen({super.key, required this.clubUuid});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ClubIncomeCubit(
        sl<ClubIncomeRepository>(), // ✅ GETIT — NOT context.read
        clubUuid,
      )..load(period: 'all'),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      body: SafeArea(
        child: BlocBuilder<ClubIncomeCubit, ClubIncomeState>(
          builder: (context, state) {
            return Column(
              children: [
                const _TopBar(),
                const SizedBox(height: 16),
                _Header(state: state),
                const SizedBox(height: 18),
                const _Filters(),
                const SizedBox(height: 18),
                Expanded(
                  child: state.loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _IncomeList(transactions: state.transactions),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/* ───────────── TOP BAR ───────────── */

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 18,
            ),
          ),
          const Spacer(),
          const Text(
            'Club Income',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/* ───────────── HEADER ───────────── */

class _Header extends StatelessWidget {
  final ClubIncomeState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final total =
        state.summary?.thisMonth ??
        state.summary?.last7Days ??
        state.summary?.allTime ??
        0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.monetization_on, color: Color(0xFFFFC107)),
        const SizedBox(width: 8),
        Text(
          '$total Coins Received',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/* ───────────── FILTERS ───────────── */

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ClubIncomeCubit>();
    final active = context.watch<ClubIncomeCubit>().state.period;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FilterChip(
            label: 'All Time',
            active: active == 'all',
            onTap: () => cubit.load(period: 'all'),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'This Month',
            active: active == 'month',
            onTap: () => cubit.load(period: 'month'),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Last 7 Days',
            active: active == '7d',
            onTap: () => cubit.load(period: '7d'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF2EFF7A)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/* ───────────── LIST ───────────── */

class _IncomeList extends StatelessWidget {
  final List<ClubTransaction> transactions;
  const _IncomeList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(
        child: Text(
          'No transactions found',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: transactions.length,
      itemBuilder: (_, i) => _IncomeTile(transaction: transactions[i]),
    );
  }
}

class _IncomeTile extends StatelessWidget {
  final ClubTransaction transaction;
  const _IncomeTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMEd().format(
      DateTime.parse(transaction.createdAt),
    );

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TransactionDetails(transaction: transaction),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B1B3A), Color(0xFF121228)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: transaction.avatarUrl != null
                  ? NetworkImage(transaction.avatarUrl!)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.fullname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.reason,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${transaction.coins} Coins',
                  style: const TextStyle(
                    color: Color(0xFFFF7A00),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────── TRANSACTION DETAILS ───────────── */

class _TransactionDetails extends StatelessWidget {
  final ClubTransaction transaction;
  const _TransactionDetails({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMMd().add_jm().format(
      DateTime.parse(transaction.createdAt),
    );

    final shareText =
        '''
🧾 Club Income Receipt

👤 Member: ${transaction.fullname}
🪙 Coins: ${transaction.coins}
📌 Reason: ${transaction.reason}
📅 Date: $date
🔗 Ref: ${transaction.txRef}
''';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14143A), Color(0xFF0F0F2D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── drag handle ───
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── amount ───
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7A00), Color(0xFFFFB347)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.45),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Text(
                      '${transaction.coins}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Coins Received',
                    style: TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 26),

                  _Row(label: 'Member', value: transaction.fullname),
                  _Row(label: 'Reason', value: transaction.reason),
                  _Row(label: 'Date', value: date),
                  _Row(
                    label: 'Reference',
                    value: transaction.txRef,
                    mono: true,
                  ),

                  const SizedBox(height: 26),

                  // ─── share button ───
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Share.share(
                          shareText,
                          subject: 'Club Income Receipt',
                        );
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text(
                        'Share Receipt',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A00),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _Row({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
