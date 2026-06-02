// lib/features/clubs/presentation/pages/club_withdrawal_detail_screen.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/domain/entities/club_treasury.dart';
import 'package:moonlight/features/clubs/data/datasources/club_treasury_remote_data_source.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_treasury_cubit.dart';
import 'package:moonlight/widgets/top_snack.dart';

import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ClubWithdrawalDetailScreen extends StatefulWidget {
  final String clubUuid;
  final String requestUuid;
  final String clubName;

  const ClubWithdrawalDetailScreen({
    super.key,
    required this.clubUuid,
    required this.requestUuid,
    required this.clubName,
  });

  @override
  State<ClubWithdrawalDetailScreen> createState() =>
      _ClubWithdrawalDetailScreenState();
}

class _ClubWithdrawalDetailScreenState
    extends State<ClubWithdrawalDetailScreen> {
  ClubWithdrawalRequest? _request;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ds = context.read<ClubTreasuryRemoteDataSource>();
      final data = await ds.getWithdrawalRequest(
        widget.clubUuid,
        widget.requestUuid,
      );
      setState(() {
        _request = ClubWithdrawalRequest.fromJson(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) TopSnack.error(context, 'Failed to load request.');
    }
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
            _load(); // reload to get updated state
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
                    if (_loading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      )
                    else if (_request == null)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Request not found',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: RefreshIndicator(
                          color: AppColors.secondary,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                            children: [
                              _StatusHeader(request: _request!),
                              const SizedBox(height: 20),
                              _AmountCard(request: _request!),
                              const SizedBox(height: 16),
                              _DetailCard(request: _request!),
                              const SizedBox(height: 16),
                              _QuorumCard(request: _request!),
                              const SizedBox(height: 16),
                              _VotesSection(request: _request!),
                              if (_request!.isCompleted) ...[
                                const SizedBox(height: 16),
                                ShareableReceiptCard(
                                  request: _request!,
                                  clubName: widget.clubName,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: _request != null && !_loading
                ? _buildActionBar(context, state)
                : null,
          );
        },
      ),
    );
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
            'Withdrawal Request',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, ClubTreasuryState state) {
    final req = _request!;
    if (!req.isPending) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          if (req.canCancel) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: state.submitting
                    ? null
                    : () => _showCancelDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel Request',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (req.canApprove) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: state.submitting
                    ? null
                    : () => _showRejectDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Reject',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: state.submitting
                    ? null
                    : () => _showApproveDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: state.submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Approve',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showApproveDialog(BuildContext context) {
    final cubit = context.read<ClubTreasuryCubit>();
    final pinCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Approve Withdrawal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Approving \$${_request!.amountUsd.toStringAsFixed(2)} for ${_request!.requester?.fullname ?? "requester"}',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _PinInputField(
                controller: pinCtrl,
                obscure: obscure,
                onToggle: () => setS(() => obscure = !obscure),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Note (optional)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    cubit.approveRequest(
                      widget.requestUuid,
                      pinCtrl.text.trim(),
                      note: noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Approval',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final cubit = context.read<ClubTreasuryCubit>();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reject Request',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please provide a reason for rejecting this request.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Reason for rejection...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (noteCtrl.text.trim().isEmpty) {
                    TopSnack.error(
                      context,
                      'Please provide a rejection reason.',
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  cubit.rejectRequest(widget.requestUuid, noteCtrl.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Reject Request',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final cubit = context.read<ClubTreasuryCubit>();
    final pinCtrl = TextEditingController();
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cancel Request',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cancelling will release the reserved coins back to the club wallet.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _PinInputField(
                controller: pinCtrl,
                obscure: obscure,
                onToggle: () => setS(() => obscure = !obscure),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    cubit.cancelRequest(
                      widget.requestUuid,
                      pinCtrl.text.trim(),
                    );
                    Navigator.pop(context); // go back after cancel
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel Request',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detail sub-widgets ────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final ClubWithdrawalRequest request;
  const _StatusHeader({required this.request});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (request.status) {
      'pending_approval' => (
        Icons.hourglass_empty_rounded,
        Colors.orange,
        'Awaiting Approval',
      ),
      'processing' => (Icons.sync_rounded, Colors.blue, 'Processing'),
      'completed' => (Icons.check_circle_rounded, Colors.green, 'Completed'),
      'failed' => (Icons.error_rounded, Colors.red, 'Failed'),
      'rejected' => (Icons.cancel_rounded, Colors.red, 'Rejected'),
      'cancelled' => (Icons.cancel_outlined, Colors.grey, 'Cancelled'),
      'expired' => (Icons.timer_off_rounded, Colors.grey, 'Expired'),
      _ => (Icons.info_rounded, Colors.grey, request.status),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (request.expiresAt != null && request.isPending)
                  Text(
                    'Expires ${_formatDateTime(request.expiresAt)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day}/${dt.month} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _AmountCard extends StatelessWidget {
  final ClubWithdrawalRequest request;
  const _AmountCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF2D1B69)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amount Requested',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${request.amountUsd.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFFFF7A00),
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          Text(
            '${request.amountCoins} coins',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: request.requester?.avatarUrl != null
                    ? NetworkImage(request.requester!.avatarUrl!)
                    : null,
                backgroundColor: Colors.white12,
              ),
              const SizedBox(width: 10),
              Text(
                'Requested by ${request.requester?.fullname ?? "Unknown"}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${request.reason}"',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final ClubWithdrawalRequest request;
  const _DetailCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payout Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (request.paymentMethod == 'flutterwave') ...[
            _DetailRow(
              label: 'Method',
              value: 'Bank Transfer',
              icon: Icons.account_balance_rounded,
            ),
            if (request.bankName != null)
              _DetailRow(
                label: 'Bank',
                value: request.bankName!,
                icon: Icons.business_rounded,
              ),
            if (request.bankAccountMasked != null)
              _DetailRow(
                label: 'Account',
                value: request.bankAccountMasked!,
                icon: Icons.credit_card_rounded,
              ),
            if (request.bankAccountName != null)
              _DetailRow(
                label: 'Account Name',
                value: request.bankAccountName!,
                icon: Icons.person_rounded,
              ),
            if (request.bankCountry != null)
              _DetailRow(
                label: 'Country',
                value: request.bankCountry!,
                icon: Icons.flag_rounded,
              ),
          ] else ...[
            _DetailRow(
              label: 'Method',
              value: 'PayPal',
              icon: Icons.payment_rounded,
            ),
            if (request.paypalEmail != null)
              _DetailRow(
                label: 'PayPal',
                value: request.paypalEmail!,
                icon: Icons.email_rounded,
              ),
          ],
          if (request.flwReference != null) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: request.flwReference!));
                TopSnack.success(context, 'Reference copied');
              },
              child: _DetailRow(
                label: 'Reference',
                value: request.flwReference!,
                icon: Icons.copy_rounded,
                valueColor: Colors.blue,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuorumCard extends StatelessWidget {
  final ClubWithdrawalRequest request;
  const _QuorumCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final progress = request.approvalsRequired == 0
        ? 1.0
        : (request.approvalsReceived / request.approvalsRequired).clamp(
            0.0,
            1.0,
          );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Approval Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${request.approvalsReceived}/${request.approvalsRequired}',
                style: TextStyle(
                  color: request.quorumReached ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                request.quorumReached ? Colors.green : const Color(0xFFFF7A00),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            request.quorumReached
                ? 'Quorum reached — processing withdrawal'
                : 'Needs ${request.approvalsRequired - request.approvalsReceived} more approval(s)',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _VotesSection extends StatelessWidget {
  final ClubWithdrawalRequest request;
  const _VotesSection({required this.request});

  @override
  Widget build(BuildContext context) {
    if (request.votes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Votes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...request.votes.map((v) => _VoteRow(vote: v)),
        ],
      ),
    );
  }
}

class _VoteRow extends StatelessWidget {
  final ClubWithdrawalVote vote;
  const _VoteRow({required this.vote});

  @override
  Widget build(BuildContext context) {
    final isApproved = vote.action == 'approved';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: vote.admin?.avatarUrl != null
                ? NetworkImage(vote.admin!.avatarUrl!)
                : null,
            backgroundColor: Colors.white12,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vote.admin?.fullname ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (vote.note != null && vote.note!.isNotEmpty)
                  Text(
                    '"${vote.note}"',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isApproved ? Colors.green : Colors.red).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isApproved ? Icons.check_rounded : Icons.close_rounded,
                  color: isApproved ? Colors.green : Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  isApproved ? 'Approved' : 'Rejected',
                  style: TextStyle(
                    color: isApproved ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _ReceiptCard extends StatelessWidget {
  final ClubWithdrawalRequest request;
  const _ReceiptCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.12),
            Colors.green.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: Colors.greenAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Transaction Receipt',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          _ReceiptRow(
            label: 'Amount',
            value: '\$${request.amountUsd.toStringAsFixed(2)}',
          ),
          _ReceiptRow(
            label: 'Coins Deducted',
            value: '${request.amountCoins} coins',
          ),
          if (request.bankName != null)
            _ReceiptRow(label: 'Bank', value: request.bankName!),
          if (request.bankAccountMasked != null)
            _ReceiptRow(label: 'Account', value: request.bankAccountMasked!),
          if (request.flwReference != null)
            _ReceiptRow(label: 'Reference', value: request.flwReference!),
          if (request.completedAt != null)
            _ReceiptRow(
              label: 'Completed',
              value:
                  '${request.completedAt!.day}/${request.completedAt!.month}/${request.completedAt!.year}',
            ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'Transfer completed successfully',
                style: TextStyle(color: Colors.greenAccent, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── PIN input used in bottom sheets ──────────────────────────────────────────

class _PinInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  const _PinInputField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Club Treasury PIN',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 8,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: '••••••',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 22,
                letterSpacing: 8,
              ),
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixIcon: const Icon(Icons.lock_rounded, color: Colors.white54),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white54,
                ),
                onPressed: onToggle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shareable Receipt Card ────────────────────────────────────────────────────
// Drop-in replacement for _ReceiptCard.
// Wrap the card in RepaintBoundary, capture on share tap.

class ShareableReceiptCard extends StatefulWidget {
  final ClubWithdrawalRequest request;
  final String clubName;

  const ShareableReceiptCard({
    super.key,
    required this.request,
    required this.clubName,
  });

  @override
  State<ShareableReceiptCard> createState() => _ShareableReceiptCardState();
}

class _ShareableReceiptCardState extends State<ShareableReceiptCard> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // 1. Find the render object
      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not find receipt widget');

      // 2. Capture at 3× device pixel ratio for crisp output
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');
      final pngBytes = byteData.buffer.asUint8List();

      // 3. Write to temp file
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/moonlight_withdrawal_${widget.request.uuid.substring(0, 8)}.png',
      );
      await file.writeAsBytes(pngBytes);

      // 4. Share
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'Club Withdrawal Receipt — ${widget.clubName}',
        text:
            'Withdrawal of \$${widget.request.amountUsd.toStringAsFixed(2)}'
            ' from ${widget.clubName} — processed via Moonlight.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The card itself — wrapped in RepaintBoundary for capture
        RepaintBoundary(
          key: _receiptKey,
          child: _ReceiptCardContent(
            request: widget.request,
            clubName: widget.clubName,
          ),
        ),

        const SizedBox(height: 12),

        // Share button below the card
        OutlinedButton.icon(
          onPressed: _sharing ? null : _share,
          icon: _sharing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.greenAccent,
                  ),
                )
              : const Icon(Icons.share_rounded, size: 18),
          label: Text(_sharing ? 'Preparing…' : 'Share Receipt'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.greenAccent,
            side: BorderSide(color: Colors.greenAccent.withOpacity(0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

// ── The visual receipt content ────────────────────────────────────────────────
// Extracted so the RepaintBoundary captures only the card,
// and the share button sits outside it (not included in the image).

class _ReceiptCardContent extends StatelessWidget {
  final ClubWithdrawalRequest request;
  final String clubName;

  const _ReceiptCardContent({required this.request, required this.clubName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Solid background — important for PNG export (no transparent regions)
        color: const Color(0xFF0D1A0D),
        gradient: LinearGradient(
          colors: [Colors.green.withOpacity(0.18), const Color(0xFF0D1A0D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Transaction Receipt',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Watermark / app name
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Moonlight',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            clubName,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Amount — large and prominent
          Center(
            child: Column(
              children: [
                Text(
                  '\$${request.amountUsd.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  '${request.amountCoins} coins deducted',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Detail rows
          if (request.paymentMethod == 'flutterwave') ...[
            _Row(label: 'Method', value: 'Bank Transfer'),
            if (request.bankName != null)
              _Row(label: 'Bank', value: request.bankName!),
            if (request.bankAccountMasked != null)
              _Row(label: 'Account', value: request.bankAccountMasked!),
            if (request.bankAccountName != null)
              _Row(label: 'Account Name', value: request.bankAccountName!),
            if (request.bankCountry != null)
              _Row(label: 'Country', value: request.bankCountry!),
          ] else ...[
            _Row(label: 'Method', value: 'PayPal'),
            if (request.paypalEmail != null)
              _Row(label: 'Email', value: request.paypalEmail!),
          ],

          if (request.flwReference != null)
            _Row(label: 'Reference', value: request.flwReference!),

          if (request.completedAt != null)
            _Row(label: 'Completed', value: _formatDate(request.completedAt!)),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Status footer
          Row(
            children: const [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'Transfer completed successfully',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
