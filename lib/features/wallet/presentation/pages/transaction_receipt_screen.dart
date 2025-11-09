import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/core/routing/route_names.dart';
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

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _opacityAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    // start the animation
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      appBar: AppBar(
        title: const Text('Transaction Receipt'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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

            // Transaction card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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

                  _buildRow('Amount Paid', formatNaira(txn.amountPaid)),
                  const SizedBox(height: 10),
                  _buildRow('Payment Method', txn.method),
                  const SizedBox(height: 10),
                  _buildRow('Transaction ID', txn.id),
                  const SizedBox(height: 10),
                  _buildRow('Date & Time', formatDate(txn.date)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // done button
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
