import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WithdrawalPinPage extends StatefulWidget {
  final int amountUsdCents;
  final String bankAccountName;
  final Function(String) onPinVerified;

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

  void _onNumberPressed(String number) {
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin.add(number);
      });

      if (_enteredPin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin.removeLast();
      });
    }
  }

  void _verifyPin() {
    final pin = _enteredPin.join();
    widget.onPinVerified(pin);
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < _enteredPin.length
                ? Colors.deepOrangeAccent
                : Colors.white24,
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
            onPressed: () => _onNumberPressed(i.toString()),
          ),
        const SizedBox.shrink(),
        _NumpadButton(text: '0', onPressed: () => _onNumberPressed('0')),
        _NumpadButton(icon: Icons.backspace, onPressed: _onBackspacePressed),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = (widget.amountUsdCents / 100).toStringAsFixed(2);

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
              const Icon(
                Icons.security,
                size: 64,
                color: Colors.deepOrangeAccent,
              ),
              const SizedBox(height: 24),
              Text(
                '\$$amount',
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

class _NumpadButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback onPressed;

  const _NumpadButton({Key? key, this.text, this.icon, required this.onPressed})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
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
    );
  }
}
