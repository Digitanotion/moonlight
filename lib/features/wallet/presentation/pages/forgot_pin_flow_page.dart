// lib/features/wallet/presentation/pages/forgot_pin_flow_page.dart
//
// Shared "Forgot PIN" flow (email OTP) for both the personal wallet PIN
// and a club's treasury withdrawal PIN. Same 3 steps either way — request
// a code, verify it, set a new PIN without needing the old one — so this
// takes the actual request/verify/reset calls as injected callbacks
// instead of being wallet- or club-specific. [pinLength] differs (wallet
// PIN is 4 digits, treasury PIN is 6).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/widgets/app_logo_loader.dart';
import 'package:moonlight/widgets/top_snack.dart';

class ForgotPinFlowPage extends StatefulWidget {
  final String title;
  final int pinLength;
  final Future<void> Function() onRequestCode;
  final Future<String> Function(String code) onVerifyCode;
  final Future<void> Function(String resetToken, String newPin) onResetPin;

  const ForgotPinFlowPage({
    super.key,
    required this.title,
    required this.pinLength,
    required this.onRequestCode,
    required this.onVerifyCode,
    required this.onResetPin,
  });

  @override
  State<ForgotPinFlowPage> createState() => _ForgotPinFlowPageState();
}

enum _Step { intro, code, newPin }

class _ForgotPinFlowPageState extends State<ForgotPinFlowPage> {
  _Step _step = _Step.intro;
  bool _busy = false;
  String? _error;
  String? _resetToken;

  final _codeCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  int _resendCooldown = 0;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown = (_resendCooldown - 1).clamp(0, 60));
      return _resendCooldown > 0;
    });
  }

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onRequestCode();
      if (!mounted) return;
      setState(() => _step = _Step.code);
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await widget.onVerifyCode(code);
      if (!mounted) return;
      setState(() {
        _resetToken = token;
        _step = _Step.newPin;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitNewPin() async {
    final newPin = _newPinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    if (newPin.length != widget.pinLength) {
      setState(
        () => _error = 'PIN must be exactly ${widget.pinLength} digits.',
      );
      return;
    }
    if (newPin != confirmPin) {
      setState(() => _error = 'PINs do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onResetPin(_resetToken!, newPin);
      if (!mounted) return;
      TopSnack.success(context, 'PIN reset. Use your new PIN next time.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring('Exception: '.length) : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060522),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            _Step.intro => _buildIntro(),
            _Step.code => _buildCodeEntry(),
            _Step.newPin => _buildNewPin(),
          },
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.mail_lock_outlined,
          color: Colors.deepOrangeAccent,
          size: 56,
        ),
        const SizedBox(height: 20),
        const Text(
          "We'll email you a 6-digit code to verify it's really you, "
          'then you can set a new PIN — no need to remember the old one.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        if (_error != null) _errorText(),
        const Spacer(),
        _primaryButton('Send code', _busy ? null : _sendCode),
      ],
    );
  }

  Widget _buildCodeEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter the code',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Check your email for a 6-digit code. It expires in 10 minutes.',
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            letterSpacing: 12,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_error != null) _errorText(),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _resendCooldown == 0 && !_busy ? _sendCode : null,
            child: Text(
              _resendCooldown == 0
                  ? 'Resend code'
                  : 'Resend code in ${_resendCooldown}s',
              style: const TextStyle(color: Colors.deepOrangeAccent),
            ),
          ),
        ),
        const Spacer(),
        _primaryButton('Verify', _busy ? null : _verifyCode),
      ],
    );
  }

  Widget _buildNewPin() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set a new ${widget.pinLength}-digit PIN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          _pinField('New PIN', _newPinCtrl),
          const SizedBox(height: 14),
          _pinField('Confirm new PIN', _confirmPinCtrl),
          if (_error != null) _errorText(),
          const SizedBox(height: 28),
          _primaryButton('Save PIN', _busy ? null : _submitNewPin),
        ],
      ),
    );
  }

  Widget _pinField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      obscureText: true,
      textAlign: TextAlign.center,
      maxLength: widget.pinLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        letterSpacing: 8,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _errorText() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      _error!,
      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
    ),
  );

  Widget _primaryButton(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF7A00),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: AppLogoLoader())
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
