// lib/features/gift_coins/presentation/pages/pin_entry_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/transfer_cubit.dart';

class PinEntryPage extends StatefulWidget {
  final String recipientUsername;
  final int amount;

  const PinEntryPage({
    Key? key,
    required this.recipientUsername,
    required this.amount,
  }) : super(key: key);

  @override
  State<PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends State<PinEntryPage> {
  static const int pinLength = 4;
  final List<int> _entered = [];
  late List<int> _keys; // randomized keys
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _randomizeKeys();
  }

  void _randomizeKeys() {
    final rng = Random();
    _keys = List<int>.generate(10, (i) => i);
    _keys.shuffle(rng);
  }

  void _onKeyTap(int v) {
    if (_entered.length >= pinLength) return;
    setState(() {
      _entered.add(v);
      _errorMessage = null;
    });
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered.removeLast();
      _errorMessage = null;
    });
  }

  Future<void> _onConfirm() async {
    if (_entered.length != pinLength) return;

    final pin = _entered.join();
    final cubit = context.read<TransferCubit>();

    // Trigger PIN verification
    await cubit.sendTransfer(pin: pin);

    final state = cubit.state;
    if (state.sendSuccess) {
      // PIN verified and transfer succeeded
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else if (state.sendError != null) {
      // Show error and reset input
      setState(() {
        _errorMessage = state.sendError!;
        _entered.clear();
        _randomizeKeys();
      });
    }
  }

  void _onForgotPin() {
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (_) => const ResetPinStartPage(),
    //     fullscreenDialog: true,
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<TransferCubit>();
    final sending = cubit.state.sending;

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF060522),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text('Enter Your Wallet Pin'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1B4D).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sending to',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@${widget.recipientUsername}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${widget.amount} Coins',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coins',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Text(
                    'Confirm This Transaction',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pinLength, (i) {
                      final filled = i < _entered.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141433),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: filled
                                ? Colors.orangeAccent
                                : Colors.white12,
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: filled
                              ? Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.orangeAccent,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      );
                    }),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        childAspectRatio: 1.6,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        children: [
                          for (int i = 0; i < 9; i++)
                            _buildKey(
                              _keys[i].toString(),
                              onTap: () => _onKeyTap(_keys[i]),
                            ),
                          _buildBlankKey(),
                          _buildKey(
                            _keys[9].toString(),
                            onTap: () => _onKeyTap(_keys[9]),
                          ),
                          _buildDeleteKey(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: sending ? null : _onForgotPin,
                              child: const Text(
                                'Forgot PIN?',
                                style: TextStyle(color: Colors.orangeAccent),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 8,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                                (_entered.length == pinLength && !sending)
                                ? _onConfirm
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (_entered.length == pinLength)
                                  ? Colors.deepOrangeAccent
                                  : Colors.deepOrangeAccent.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: sending
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Confirm Transfer'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String label, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141433),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _onDelete,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141433),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: const Center(
            child: Icon(Icons.backspace_outlined, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildBlankKey() => const SizedBox.shrink();
}
