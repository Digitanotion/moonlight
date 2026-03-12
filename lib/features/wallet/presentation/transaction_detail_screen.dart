// lib/features/wallet/presentation/pages/transaction_detail_screen.dart
//
// ── WIRING ────────────────────────────────────────────────────────────────────
// route_names.dart:
//   static const transactionDetail = '/wallet/transaction-detail';
//
// app_router.dart:
//   case RouteNames.transactionDetail:
//     final txn = settings.arguments as TransactionModel;
//     return MaterialPageRoute(
//       builder: (_) => TransactionDetailScreen(transaction: txn),
//     );
//
// pubspec.yaml (if not already present):
//   share_plus: ^7.0.0
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:moonlight/features/wallet/domain/models/transaction_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:moonlight/core/utils/formatting.dart';

// ─── helpers ─────────────────────────────────────────────────────────────────

String _typeLabel(String type) {
  switch (type) {
    case 'purchase':
      return 'Coin Purchase';
    case 'gift_out':
      return 'Gift Sent';
    case 'gift_received':
    case 'earning':
      return 'Gift Received';
    case 'transfer_in':
      return 'Coins Received';
    case 'transfer_out':
      return 'Coins Sent';
    case 'withdrawal':
      return 'Withdrawal';
    case 'withdrawal_refund':
      return 'Withdrawal Refunded';
    default:
      return type
          .split('_')
          .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
          .join(' ');
  }
}

IconData _typeIcon(String type) {
  switch (type) {
    case 'purchase':
      return Icons.shopping_bag_rounded;
    case 'gift_out':
      return Icons.card_giftcard_rounded;
    case 'gift_received':
    case 'earning':
      return Icons.favorite_rounded;
    case 'transfer_in':
      return Icons.arrow_downward_rounded;
    case 'transfer_out':
      return Icons.arrow_upward_rounded;
    case 'withdrawal':
      return Icons.account_balance_rounded;
    case 'withdrawal_refund':
      return Icons.undo_rounded;
    default:
      return Icons.swap_horiz_rounded;
  }
}

List<Color> _typeGradient(String type) {
  switch (type) {
    case 'purchase':
      return [const Color(0xFFFF7A00), const Color(0xFFFF4500)];
    case 'gift_out':
      return [const Color(0xFFE91E8C), const Color(0xFF9C27B0)];
    case 'gift_received':
    case 'earning':
      return [const Color(0xFF4CAF50), const Color(0xFF00BCD4)];
    case 'transfer_in':
      return [const Color(0xFF00BCD4), const Color(0xFF2196F3)];
    case 'transfer_out':
      return [const Color(0xFF9C27B0), const Color(0xFF3F51B5)];
    case 'withdrawal':
      return [const Color(0xFFFF5722), const Color(0xFFF44336)];
    case 'withdrawal_refund':
      return [const Color(0xFF607D8B), const Color(0xFF455A64)];
    default:
      return [const Color(0xFF607D8B), const Color(0xFF37474F)];
  }
}

bool _isCredit(String type) =>
    type == 'purchase' ||
    type == 'gift_received' ||
    type == 'earning' ||
    type == 'transfer_in' ||
    type == 'withdrawal_refund';

// ─── screen ──────────────────────────────────────────────────────────────────

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({Key? key, required this.transaction})
    : super(key: key);

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _receiptKey = GlobalKey();
  bool _sharing = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _shareAsImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    HapticFeedback.mediumImpact();

    try {
      // Brief delay so the widget finishes painting before capture
      await Future.delayed(const Duration(milliseconds: 80));

      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Receipt widget not found');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Could not encode image');

      final pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'moonlight_txn_${widget.transaction.id}.png',
      );

      await Share.shareXFiles([xFile], subject: 'My Moonlight Transaction');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071032), Color(0xFF040407)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onShare: _sharing ? null : _shareAsImage,
                sharing: _sharing,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: RepaintBoundary(
                        key: _receiptKey,
                        child: _ReceiptCard(transaction: widget.transaction),
                      ),
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

// ─── top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback? onShare;
  final bool sharing;

  const _TopBar({required this.onShare, required this.sharing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.maybePop(context),
          ),
          const Spacer(),
          const Text(
            'Transaction Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          sharing
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                )
              : _NavButton(
                  icon: Icons.ios_share_rounded,
                  onTap: onShare,
                  disabled: onShare == null,
                ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  const _NavButton({required this.icon, this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: disabled ? Colors.white10 : Colors.white30,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: disabled ? Colors.white24 : Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

// ─── receipt card ─────────────────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  final TransactionModel transaction;
  const _ReceiptCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final txn = transaction;
    final credit = _isCredit(txn.type);
    final coinColor = credit
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFF5252);
    final gradient = _typeGradient(txn.type);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1B47), Color(0xFF1A0D3A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── header ──────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradient[0].withOpacity(0.18),
                  gradient[1].withOpacity(0.06),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Icon badge
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _typeIcon(txn.type),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _typeLabel(txn.type),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('MMM d, yyyy  ·  h:mm a').format(txn.date),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ── coin amount ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Column(
              children: [
                Text(
                  '${credit ? '+' : ''}${txn.coinsChange} Coins',
                  style: TextStyle(
                    color: coinColor,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                if (txn.amountPaid > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    formatusd(txn.amountPaid),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── dashed divider ───────────────────────────────────────────────────
          const _DashedDivider(),
          const SizedBox(height: 4),

          // ── detail rows ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(children: _buildRows(txn, credit, coinColor)),
          ),

          // ── branding footer ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFFFD54F),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  'Moonlight Wallet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRows(TransactionModel txn, bool credit, Color coinColor) {
    final rows = <Widget>[];

    void add(
      String label,
      dynamic value, {
      Color? valueColor,
      bool mono = false,
      bool small = false,
    }) {
      rows.add(
        _DetailRow(
          label: label,
          value: value,
          valueColor: valueColor,
          mono: mono,
          small: small,
        ),
      );
    }

    // Status
    final isPending =
        txn.type == 'withdrawal' &&
        (txn.meta?['flw_status'] == 'pending' ||
            txn.meta?['flw_status'] == null);
    add(
      'Status',
      _StatusBadge(
        label: isPending ? 'Pending' : 'Completed',
        color: isPending ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
      ),
    );

    add('Type', _typeLabel(txn.type));

    // Method
    final methodDisplay = txn.method
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
    add('Method', methodDisplay);

    if (txn.amountPaid > 0) add('Amount Paid', formatusd(txn.amountPaid));

    add(
      'Coins',
      '${credit ? '+' : ''}${txn.coinsChange}',
      valueColor: coinColor,
    );

    if (txn.balanceAfter != null) {
      add('Balance After', '${txn.balanceAfter} coins');
    }

    // Related user
    if (txn.relatedUserName != null) {
      final userLabel = () {
        switch (txn.type) {
          case 'gift_out':
          case 'transfer_out':
            return 'Recipient';
          case 'earning':
          case 'transfer_in':
            return 'Sender';
          default:
            return 'User';
        }
      }();
      add(userLabel, txn.relatedUserName!);
    }

    // Meta extras
    final giftCode = txn.meta?['gift_code'] as String?;
    if (giftCode != null) add('Gift', giftCode);

    final livestreamId = txn.meta?['livestream_id'];
    if (livestreamId != null) add('Livestream', livestreamId.toString());

    // Withdrawal specifics
    if (txn.type == 'withdrawal') {
      final bankName = txn.meta?['bank_name'] as String?;
      final accountName = txn.meta?['account_name'] as String?;
      if (bankName != null) add('Bank', bankName);
      if (accountName != null) add('Account Name', accountName);
    }

    // IDs
    add('Transaction ID', txn.id, mono: true, small: true);
    add(
      'Date',
      DateFormat('MMM d, yyyy h:mm:ss a').format(txn.date),
      small: true,
    );

    return rows;
  }
}

// ─── detail row ───────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final dynamic value; // String or Widget
  final Color? valueColor;
  final bool mono;
  final bool small;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 11.5 : 13.0;

    Widget valueWidget;
    if (value is Widget) {
      valueWidget = value as Widget;
    } else {
      valueWidget = Text(
        value.toString(),
        textAlign: TextAlign.end,
        style: TextStyle(
          color: valueColor ?? Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null,
          letterSpacing: mono ? -0.4 : 0,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white54, fontSize: fontSize),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: valueWidget),
          ),
        ],
      ),
    );
  }
}

// ─── status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ─── dashed divider ───────────────────────────────────────────────────────────

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashW = 6.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dashW + gap)).floor();
        return Row(
          children: List.generate(count, (_) {
            return Padding(
              padding: const EdgeInsets.only(right: gap),
              child: Container(width: dashW, height: 1, color: Colors.white12),
            );
          }),
        );
      },
    );
  }
}
