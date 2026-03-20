import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/models/transaction_model.dart';

class TransactionReceiptScreen extends StatefulWidget {
  static const routeName = RouteNames.transactionReceipt;
  const TransactionReceiptScreen({Key? key}) : super(key: key);

  @override
  State<TransactionReceiptScreen> createState() =>
      _TransactionReceiptScreenState();
}

class _TransactionReceiptScreenState extends State<TransactionReceiptScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  // Key wraps only the receipt card — not the whole screen
  final GlobalKey _receiptKey = GlobalKey();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _opacityAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Capture receipt card as image ────────────────────────────────────────────
  Future<File?> _captureReceiptAsImage() async {
    try {
      // Wait for any ongoing animations/renders to settle
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/moonlight_receipt_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      debugPrint('Receipt capture error: $e');
      return null;
    }
  }

  // ── Share receipt ─────────────────────────────────────────────────────────────
  Future<void> _shareReceipt(TransactionModel txn) async {
    setState(() => _isSaving = true);
    try {
      final file = await _captureReceiptAsImage();
      if (file == null) {
        _showSnack('Failed to capture receipt');
        return;
      }
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Moonlight purchase receipt — ${txn.coinsChange} coins · ${formatDate(txn.date)}',
        subject: 'Moonlight Transaction Receipt',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Save receipt to gallery ───────────────────────────────────────────────────
  Future<void> _saveToGallery(TransactionModel txn) async {
    setState(() => _isSaving = true);
    try {
      final file = await _captureReceiptAsImage();
      if (file == null) {
        _showSnack('Failed to capture receipt');
        return;
      }

      // Use image_gallery_saver or gal package if available.
      // Fallback: save to documents directory and inform user.
      final docsDir = await getApplicationDocumentsDirectory();
      final savedFile = File(
        '${docsDir.path}/moonlight_receipt_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.copy(savedFile.path);

      _showSnack('Receipt saved to app documents ✓');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1B1030),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txn = ModalRoute.of(context)!.settings.arguments as TransactionModel?;
    if (txn == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt')),
        body: const Center(child: Text('No transaction data')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      // appBar: AppBar(
      //   title: const Text('Transaction Receipt'),
      //   backgroundColor: Colors.transparent,
      //   elevation: 0,
      //   actions: [
      //     // Share button in app bar for quick access
      //     if (!_isSaving)
      //       IconButton(
      //         onPressed: () => _shareReceipt(txn),
      //         icon: const Icon(Icons.share_rounded, color: Colors.white),
      //         tooltip: 'Share receipt',
      //       ),
      //   ],
      // ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0B24), Color(0xFF1C1335)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 100),

            // ── Success icon ────────────────────────────────────────────────
            Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: FadeTransition(
                  opacity: _opacityAnim,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Payment Successful!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your transaction has been processed securely.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 30),

            // ── Receipt card — wrapped in RepaintBoundary for capture ───────
            RepaintBoundary(
              key: _receiptKey,
              child: Container(
                // Opaque background so the screenshot has no transparency
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D0B24), Color(0xFF1C1335)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1030).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        size: 50,
                        color: Colors.amberAccent,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${formatCoin(txn.coinsChange)} Coins',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Successfully purchased',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const Divider(
                        height: 32,
                        color: Colors.white12,
                        thickness: 1,
                      ),
                      _buildRow(
                        'Amount Paid (USD)',
                        '\$${txn.amountPaid.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 10),
                      if (txn.meta?['actual_price_paid'] != null) ...[
                        _buildRow(
                          'Local Price (${txn.meta?['actual_price_currency'] ?? 'local'})',
                          txn.meta!['actual_price_paid'].toString(),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _buildRow('Payment Method', txn.method),
                      const SizedBox(height: 10),
                      _buildRow('Transaction ID', txn.id),
                      const SizedBox(height: 10),
                      _buildRow('Date & Time', formatDate(txn.date)),
                      const SizedBox(height: 16),

                      // ── Branding footer (visible in screenshot) ─────────
                      const Divider(height: 24, color: Colors.white12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.nights_stay_rounded,
                            color: Color(0xFFFF7A00),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Moonlight · moonlightstream.app',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Share & Save buttons ────────────────────────────────────────
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(color: Color(0xFFFF7A00)),
                ),
              )
            else
              Row(
                children: [
                  // Share
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareReceipt(txn),
                      icon: const Icon(
                        Icons.share_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      label: const Text(
                        'Share',
                        style: TextStyle(color: Colors.white70),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Save as image
                  // Expanded(
                  //   child: OutlinedButton.icon(
                  //     onPressed: () => _saveToGallery(txn),
                  //     icon: const Icon(
                  //       Icons.download_rounded,
                  //       color: Colors.white70,
                  //       size: 18,
                  //     ),
                  //     label: const Text(
                  //       'Save Image',
                  //       style: TextStyle(color: Colors.white70),
                  //     ),
                  //     style: OutlinedButton.styleFrom(
                  //       side: const BorderSide(color: Colors.white24),
                  //       padding: const EdgeInsets.symmetric(vertical: 14),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),

            const SizedBox(height: 16),

            // ── Done button ─────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () => Navigator.popUntil(
                context,
                ModalRoute.withName(RouteNames.wallet),
              ),
              icon: const Icon(Icons.done_all_rounded, color: Colors.white),
              label: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
