// lib/features/clubs/presentation/pages/club_treasury_audit_log_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/data/datasources/club_treasury_remote_data_source.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_treasury_cubit.dart';

class ClubTreasuryAuditLogScreen extends StatefulWidget {
  final String clubUuid;

  const ClubTreasuryAuditLogScreen({super.key, required this.clubUuid});

  @override
  State<ClubTreasuryAuditLogScreen> createState() =>
      _ClubTreasuryAuditLogScreenState();
}

class _ClubTreasuryAuditLogScreenState
    extends State<ClubTreasuryAuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = context.read<ClubTreasuryRemoteDataSource>();
      final logs = await ds.getAuditLog(widget.clubUuid);
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : _logs.isEmpty
                    ? _EmptyView()
                    : RefreshIndicator(
                        color: AppColors.secondary,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          itemCount: _logs.length,
                          itemBuilder: (_, i) => _AuditLogItem(log: _logs[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Treasury Audit Log',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'All treasury actions — immutable record',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _load,
          ),
        ],
      ),
    );
  }
}

// ── Audit Log Item ────────────────────────────────────────────────────────────

class _AuditLogItem extends StatelessWidget {
  final Map<String, dynamic> log;
  const _AuditLogItem({required this.log});

  @override
  Widget build(BuildContext context) {
    final eventType = log['event_type'] as String? ?? 'unknown';
    final actor = log['actor'] as Map<String, dynamic>?;
    final meta = log['meta'] as Map<String, dynamic>? ?? {};
    final createdAt = log['created_at'] != null
        ? DateTime.tryParse(log['created_at'])
        : null;

    final (icon, color, label) = _eventInfo(eventType);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _timeAgo(createdAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (actor != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: actor['avatar_url'] != null
                            ? NetworkImage(actor['avatar_url'])
                            : null,
                        backgroundColor: Colors.white12,
                        child: actor['avatar_url'] == null
                            ? const Icon(
                                Icons.person,
                                size: 10,
                                color: Colors.white54,
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        actor['fullname'] ?? actor['user_slug'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _MetaChips(meta: meta, eventType: eventType),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _eventInfo(String type) {
    return switch (type) {
      'pin_set' => (Icons.lock_rounded, Colors.greenAccent, 'Treasury PIN Set'),
      'pin_changed' => (
        Icons.lock_reset_rounded,
        Colors.orange,
        'Treasury PIN Changed',
      ),
      'policy_updated' => (
        Icons.tune_rounded,
        Colors.purpleAccent,
        'Withdrawal Policy Updated',
      ),
      'payout_profile_updated' => (
        Icons.account_balance_rounded,
        Colors.blueAccent,
        'Payout Profile Updated',
      ),
      'request_submitted' => (
        Icons.arrow_upward_rounded,
        Colors.orange,
        'Withdrawal Request Submitted',
      ),
      'request_approved' => (
        Icons.check_rounded,
        Colors.greenAccent,
        'Request Approved',
      ),
      'request_rejected' => (
        Icons.close_rounded,
        Colors.red,
        'Request Rejected',
      ),
      'request_cancelled' => (
        Icons.cancel_rounded,
        Colors.grey,
        'Request Cancelled',
      ),
      'request_expired' => (
        Icons.timer_off_rounded,
        Colors.grey,
        'Request Expired',
      ),
      'withdrawal_executed' => (
        Icons.send_rounded,
        Colors.blueAccent,
        'Withdrawal Executed',
      ),
      'withdrawal_completed' => (
        Icons.check_circle_rounded,
        Colors.greenAccent,
        'Withdrawal Completed ✓',
      ),
      'withdrawal_failed' => (
        Icons.error_rounded,
        Colors.red,
        'Withdrawal Failed',
      ),
      'coins_refunded' => (Icons.undo_rounded, Colors.orange, 'Coins Refunded'),
      _ => (Icons.history_rounded, Colors.white38, type),
    };
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _MetaChips extends StatelessWidget {
  final Map<String, dynamic> meta;
  final String eventType;
  const _MetaChips({required this.meta, required this.eventType});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (meta['amount_usd'] != null) {
      chips.add(
        _Chip(label: '\$${meta['amount_usd']}', color: const Color(0xFFFF7A00)),
      );
    }
    if (meta['amount_coins'] != null) {
      chips.add(
        _Chip(label: '${meta['amount_coins']} coins', color: Colors.amber),
      );
    }
    if (meta['note'] != null && meta['note'].toString().isNotEmpty) {
      chips.add(
        _Chip(label: '"${meta['note']}"', color: Colors.white38, maxWidth: 180),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final double? maxWidth;
  const _Chip({required this.label, required this.color, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: maxWidth != null
          ? BoxConstraints(maxWidth: maxWidth!)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            color: Colors.white.withOpacity(0.2),
            size: 60,
          ),
          const SizedBox(height: 16),
          const Text(
            'No audit events yet',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Treasury actions will appear here',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
