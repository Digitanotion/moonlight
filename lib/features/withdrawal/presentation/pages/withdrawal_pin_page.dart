// lib/features/withdrawal/presentation/pages/withdrawal_pin_page.dart

import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';

class WithdrawalPinPage extends StatefulWidget {
  final int amountUsdCents;
  final String bankAccountName;

  /// Changed to Future<void> so this page can await it and catch errors.
  final Future<void> Function(String pin) onPinVerified;

  const WithdrawalPinPage({
    Key? key,
    required this.amountUsdCents,
    required this.bankAccountName,
    required this.onPinVerified,
  }) : super(key: key);

  @override
  State<WithdrawalPinPage> createState() => _WithdrawalPinPageState();
}

class _WithdrawalPinPageState extends State<WithdrawalPinPage> {
  final List<String> _enteredPin = [];
  final int _pinLength = 4;

  bool _isVerifying = false;
  String? _errorText;

  // ── PIN-not-set detection ──────────────────────────────────────────────

  bool _isPinNotSet(String msg) {
    final s = msg.toLowerCase();
    return s.contains('no pin') ||
        s.contains('pin not set') ||
        s.contains('pin_not_set') ||
        s.contains('wallet pin') ||
        s.contains('invalid pin') ||
        s.contains('wallet not found') ||
        s.isEmpty;
  }

  // ── Input ──────────────────────────────────────────────────────────────

  void _onNumberPressed(String number) {
    if (_isVerifying || _enteredPin.length >= _pinLength) return;
    setState(() {
      _errorText = null;
      _enteredPin.add(number);
    });
    if (_enteredPin.length == _pinLength) _submitPin();
  }

  void _onBackspacePressed() {
    if (_isVerifying || _enteredPin.isEmpty) return;
    setState(() {
      _errorText = null;
      _enteredPin.removeLast();
    });
  }

  void _clearPin() => setState(() {
    _enteredPin.clear();
    _errorText = null;
  });

  // ── Submit ─────────────────────────────────────────────────────────────

  Future<void> _submitPin() async {
    final pin = _enteredPin.join();
    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      await widget.onPinVerified(pin);
      // Success — caller (WithdrawalPage) already popped this page.
    } catch (e) {
      if (!mounted) return;

      final msg = e
          .toString()
          .replaceAll('Exception:', '')
          .replaceAll('exception:', '')
          .trim();

      if (_isPinNotSet(msg)) {
        _clearPin();
        setState(() => _isVerifying = false);
        _showNoPinDialog();
      } else {
        // Wrong PIN — show inline error then auto-clear after 600 ms
        setState(() {
          _isVerifying = false;
          _errorText = msg.isNotEmpty ? msg : 'Incorrect PIN. Try again.';
        });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) _clearPin();
      }
    }
  }

  // ── No-PIN dialog ──────────────────────────────────────────────────────

  void _showNoPinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1533),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.lock_outline, color: Color(0xFFFF7A00), size: 56),
            SizedBox(height: 10),
            Text(
              'Wallet PIN Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: const Text(
          "You haven't set a wallet PIN yet.\n\n"
          "A PIN is required to authorise every withdrawal and "
          "keeps your earnings safe.",
          style: TextStyle(color: Colors.white70, height: 1.55),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // Dismiss — go all the way back to the withdrawal form
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close pin page → back to form
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Not now'),
          ),
          const SizedBox(width: 8),
          // CTA → SetNewPinPage
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_open, size: 18),
            label: const Text(
              'Set PIN Now',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context); // close dialog — pin page still open
              // Push SetNewPinPage; when user comes back PIN page is ready
              await Navigator.pushNamed(context, RouteNames.setNewPin);
              // PIN page is now the top — user can enter their new PIN
            },
          ),
        ],
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────

  Widget _buildPinDots() {
    final hasError = _errorText != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
        final filled = i < _enteredPin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? Colors.redAccent
                : filled
                ? Colors.deepOrangeAccent
                : Colors.white24,
            boxShadow: filled && !hasError
                ? [
                    BoxShadow(
                      color: Colors.deepOrangeAccent.withOpacity(0.45),
                      blurRadius: 7,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildNumpad() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (int i = 1; i <= 9; i++)
          _NumpadButton(
            text: i.toString(),
            disabled: _isVerifying,
            onPressed: () => _onNumberPressed(i.toString()),
          ),
        const SizedBox.shrink(),
        _NumpadButton(
          text: '0',
          disabled: _isVerifying,
          onPressed: () => _onNumberPressed('0'),
        ),
        _NumpadButton(
          icon: Icons.backspace,
          disabled: _isVerifying,
          onPressed: _onBackspacePressed,
        ),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // amountUsdCents ÷ 100 → dollars
    final amountDisplay = (widget.amountUsdCents / 100).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: const Color(0xFF060522),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Enter PIN', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Spacer(flex: 2),
          Column(
            children: [
              // Icon swaps to spinner while verifying
              _isVerifying
                  ? const SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.deepOrangeAccent,
                      ),
                    )
                  : Icon(
                      _errorText != null ? Icons.lock_open : Icons.security,
                      size: 64,
                      color: _errorText != null
                          ? Colors.redAccent
                          : Colors.deepOrangeAccent,
                    ),
              const SizedBox(height: 24),
              Text(
                '\$$amountDisplay',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Withdrawal to ${widget.bankAccountName}',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildPinDots(),
              // Inline error message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _errorText != null
                    ? Padding(
                        key: ValueKey(_errorText),
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          _errorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox(key: ValueKey('none'), height: 14),
              ),
            ],
          ),
          const Spacer(flex: 3),
          _buildNumpad(),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

// ── Numpad button ──────────────────────────────────────────────────────────

class _NumpadButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool disabled;

  const _NumpadButton({
    Key? key,
    this.text,
    this.icon,
    required this.onPressed,
    this.disabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedOpacity(
            opacity: disabled ? 0.35 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: Colors.white, size: 24)
                    : Text(
                        text!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
