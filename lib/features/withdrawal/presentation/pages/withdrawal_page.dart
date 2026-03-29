// lib/features/withdrawal/presentation/pages/withdrawal_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/utils/formatting.dart';
import '../cubit/withdrawal_cubit.dart';
import 'withdrawal_pin_page.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Nigeria NUBAN is always exactly 10 digits → resolve immediately on hit.
// All other FLW-supported countries vary (9-16 digits) → 600 ms debounce.
// ─────────────────────────────────────────────────────────────────────────────
const int _kNubanLength = 10;

enum _PaymentMethod { flutterwave, paypal }

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class WithdrawalPage extends StatefulWidget {
  const WithdrawalPage({Key? key}) : super(key: key);

  @override
  State<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends State<WithdrawalPage> {
  // ── Form ───────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Shared controllers ─────────────────────────────────────────────────────
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  // ── Flutterwave controllers ────────────────────────────────────────────────
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _swiftCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // ── PayPal controllers ─────────────────────────────────────────────────────
  final _paypalEmailController = TextEditingController();
  final _paypalEmailConfirmController = TextEditingController();

  // ── State flags ────────────────────────────────────────────────────────────
  bool _isSubmitting = false;
  bool _loadingBanks = false;
  bool _resolvingAccountName = false;
  String? _accountNameError;

  int _withdrawableCents = 0;

  _PaymentMethod _selectedMethod = _PaymentMethod.flutterwave;
  String _selectedCountry = 'Nigeria';
  final List<String> _countries = [
    'Nigeria',
    'Ghana',
    'Kenya',
    'South Africa',
    'Uganda',
    'Tanzania',
  ];

  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _selectedBank;

  // ── Debounce timer ─────────────────────────────────────────────────────────
  Timer? _accountResolutionTimer;

  // ── Computed ───────────────────────────────────────────────────────────────
  double get _enteredDollars =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  double get _enteredCents => _enteredDollars;

  double get _withdrawableDollars => _withdrawableCents * 0.005;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WithdrawalCubit>().loadBalance();
      _fetchBanks(_selectedCountry);
    });
  }

  @override
  void dispose() {
    _accountResolutionTimer?.cancel();
    _amountController.dispose();
    _reasonController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _swiftCodeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _paypalEmailController.dispose();
    _paypalEmailConfirmController.dispose();
    super.dispose();
  }

  // ── Bank fetch ─────────────────────────────────────────────────────────────

  Future<void> _fetchBanks(String country) async {
    setState(() {
      _loadingBanks = true;
      _selectedBank = null;
      _banks = [];
      _accountNameController.clear();
      _accountNameError = null;
    });
    try {
      final banks = await context.read<WithdrawalCubit>().fetchBanks(country);
      if (mounted) setState(() => _banks = banks);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load banks: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  // ── Account name resolution ────────────────────────────────────────────────

  void _onAccountNumberChanged(String value) {
    final number = value.trim();
    final bank = _selectedBank;

    // Always clear previous result when number changes
    setState(() {
      _accountNameController.clear();
      _accountNameError = null;
      _resolvingAccountName = false;
    });
    _accountResolutionTimer?.cancel();

    if (bank == null || number.length < _kNubanLength) return;

    // Nigeria (NUBAN): exactly 10 digits → fire immediately, no debounce
    if (number.length == _kNubanLength) {
      _triggerResolution(number, bank);
      return;
    }

    // Other countries (>10 digits): debounce 600 ms after user stops typing
    setState(() => _resolvingAccountName = true);
    _accountResolutionTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _triggerResolution(number, bank);
    });
  }

  void _onBankSelected(Map<String, dynamic> bank) {
    setState(() {
      _selectedBank = bank;
      _accountNameController.clear();
      _accountNameError = null;
      _resolvingAccountName = false;
    });
    _accountResolutionTimer?.cancel();

    final number = _accountNumberController.text.trim();
    if (number.length >= _kNubanLength) {
      _triggerResolution(number, bank);
    }
  }

  void _triggerResolution(String number, Map<String, dynamic> bank) {
    setState(() {
      _resolvingAccountName = true;
      _accountNameError = null;
    });
    context.read<WithdrawalCubit>().resolveAccountName(
      accountNumber: number,
      bankCode: bank['code']?.toString() ?? '',
    );
  }

  // ── Bank search sheet ──────────────────────────────────────────────────────

  void _openBankSearchSheet() {
    if (_banks.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1533),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BankSearchSheet(
        banks: _banks,
        onSelected: (bank) {
          Navigator.pop(context);
          _onBankSelected(bank);
        },
      ),
    );
  }

  // ── PIN / error helpers ────────────────────────────────────────────────────

  bool _isPinNotSet(String msg) {
    final s = msg.toLowerCase();
    return s.contains('no pin') ||
        s.contains('pin not set') ||
        s.contains('please set a wallet pin') ||
        s.isEmpty;
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

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
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
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
              Navigator.pop(context);
              await Navigator.pushNamed(context, RouteNames.setNewPin);
              if (mounted) context.read<WithdrawalCubit>().loadBalance();
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    final method = data['data']?['method']?.toString() ?? 'bank transfer';
    final flwStatus = (data['data']?['flw_status'] ?? '')
        .toString()
        .toUpperCase();
    final ppStatus = (data['data']?['paypal_status'] ?? '')
        .toString()
        .toUpperCase();
    final statusLabel = method == 'paypal'
        ? (ppStatus.isNotEmpty ? ppStatus : 'PROCESSING')
        : (flwStatus.isNotEmpty ? flwStatus : 'PENDING');

    final recipientLabel = _selectedMethod == _PaymentMethod.paypal
        ? _paypalEmailController.text
        : '${_accountNameController.text}'
              '${_selectedBank != null ? " — ${_selectedBank!['name']}" : ""}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1533),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Withdrawal Initiated!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '\$${_enteredDollars.toStringAsFixed(2)} is being transferred to $recipientLabel.',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Status: $statusLabel',
              style: const TextStyle(
                color: Colors.deepOrangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Funds are typically delivered within minutes.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.deepOrangeAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message, {bool retryable = false}) {
    if (_isPinNotSet(message)) {
      _showNoPinDialog();
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1533),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.error, color: Colors.red, size: 64),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actions: [
          if (retryable)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<WithdrawalCubit>().retryWithdrawal();
              },
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.deepOrangeAccent),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              retryable ? 'Cancel' : 'OK',
              style: const TextStyle(color: Colors.deepOrangeAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit routing ─────────────────────────────────────────────────────────

  Future<void> _submitFlutterwave(String pin) async {
    await context.read<WithdrawalCubit>().submitWithdrawal(
      amountUsdCents: _enteredCents,
      bankAccountName: _accountNameController.text.trim(),
      bankAccountNumber: _accountNumberController.text.trim(),
      bankName: _selectedBank?['name']?.toString() ?? '',
      bankCode: _selectedBank?['code']?.toString() ?? '',
      country: _selectedCountry,
      swift: _swiftCodeController.text.isNotEmpty
          ? _swiftCodeController.text.trim()
          : null,
      email: _emailController.text.isNotEmpty
          ? _emailController.text.trim()
          : null,
      phone: _phoneController.text.isNotEmpty
          ? _phoneController.text.trim()
          : null,
      reason: _reasonController.text.isNotEmpty
          ? _reasonController.text.trim()
          : null,
      pin: pin,
    );
  }

  Future<void> _submitPayPal(String pin) async {
    await context.read<WithdrawalCubit>().submitPayPalWithdrawal(
      amountUsd: _enteredCents,
      paypalEmail: _paypalEmailController.text.trim(),
      paypalEmailConfirm: _paypalEmailConfirmController.text.trim(),
      reason: _reasonController.text.isNotEmpty
          ? _reasonController.text.trim()
          : null,
      pin: pin,
    );
  }

  void _onProceedToPin() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMethod == _PaymentMethod.flutterwave) {
      if (_selectedBank == null) {
        _showErrorDialog('Please select your bank.');
        return;
      }
      if (_resolvingAccountName) {
        _showErrorDialog('Please wait — verifying your account number…');
        return;
      }
      if (_accountNameController.text.trim().isEmpty) {
        _showErrorDialog(
          'Account name could not be verified. Please check your account number and bank.',
        );
        return;
      }
    }

    final displayName = _selectedMethod == _PaymentMethod.paypal
        ? _paypalEmailController.text.trim()
        : _accountNameController.text.trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WithdrawalPinPage(
          amountUsdCents: _enteredCents,
          bankAccountName: displayName,
          onPinVerified: (pin) async {
            Navigator.pop(context); // dismiss PIN page
            if (_selectedMethod == _PaymentMethod.paypal) {
              await _submitPayPal(pin);
            } else {
              await _submitFlutterwave(pin);
            }
          },
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Available for Withdrawal',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            formatusd(_withdrawableDollars),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Minimum: \$100.00',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Withdrawal Method',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MethodCard(
                  label: 'Bank Transfer',
                  sublabel: 'via Flutterwave',
                  icon: Icons.account_balance,
                  accentColor: const Color(0xFFF5A623),
                  selected: _selectedMethod == _PaymentMethod.flutterwave,
                  onTap: () {
                    if (_selectedMethod != _PaymentMethod.flutterwave) {
                      setState(
                        () => _selectedMethod = _PaymentMethod.flutterwave,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodCard(
                  label: 'PayPal',
                  sublabel: 'Instant to email',
                  icon: Icons.send_to_mobile,
                  accentColor: const Color(0xFF003087),
                  selected: _selectedMethod == _PaymentMethod.paypal,
                  onTap: () {
                    if (_selectedMethod != _PaymentMethod.paypal) {
                      setState(() => _selectedMethod = _PaymentMethod.paypal);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amount (USD)',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141433),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '\$',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '100.00',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 20),
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                    errorStyle: TextStyle(color: Colors.redAccent),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    // Trigger FX preview when amount changes and we have a country selected
                    final dollars = double.tryParse(value.trim()) ?? 0.0;
                    if (dollars >= 100 &&
                        _selectedMethod == _PaymentMethod.flutterwave) {
                      context.read<WithdrawalCubit>().loadFxPreview(
                        amountUsd: dollars,
                        country: _selectedCountry,
                      );
                    }
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter an amount';
                    final dollars = double.tryParse(v) ?? 0.0;
                    final cents = (dollars * 100).round();
                    if (cents < 10000) return 'Minimum withdrawal is \$100.00';
                    if (cents > _withdrawableCents) {
                      return 'Exceeds your available balance of '
                          '\$${_withdrawableDollars.toStringAsFixed(2)}';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        if (_enteredDollars >= 100)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'You will receive: \$${_enteredDollars.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Flutterwave form ───────────────────────────────────────────────────────

  Widget _buildFlutterwaveForm() {
    return Column(
      children: [
        _buildCountryDropdown(),
        _buildBankSelector(),
        _buildAccountNumberField(),
        _buildAccountNameField(),

        // FX Preview - shows estimated local currency amount
        _FxPreviewWidget(
          amountUsd: _enteredDollars,
          country: _selectedCountry,
          enabled:
              _selectedMethod == _PaymentMethod.flutterwave &&
              _enteredDollars >= 100 &&
              _selectedBank != null,
        ),

        _buildInputField(
          label: 'Email (Optional)',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (_) => null,
        ),
        _buildInputField(
          label: 'Phone (Optional)',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          validator: (_) => null,
        ),
      ],
    );
  }

  // ── Searchable bank selector ───────────────────────────────────────────────

  Widget _buildBankSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bank',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Tappable pill that opens the search sheet
        GestureDetector(
          onTap: _loadingBanks || _banks.isEmpty ? null : _openBankSearchSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF141433),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedBank != null
                    ? Colors.deepOrangeAccent.withOpacity(0.45)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _loadingBanks
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.deepOrangeAccent,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Loading banks…',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        )
                      : _banks.isEmpty
                      ? Row(
                          children: [
                            const Text(
                              'No banks loaded',
                              style: TextStyle(color: Colors.white38),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _fetchBanks(_selectedCountry),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                  color: Colors.deepOrangeAccent,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _selectedBank?['name']?.toString() ??
                              'Tap to search your bank',
                          style: TextStyle(
                            color: _selectedBank != null
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 15,
                          ),
                        ),
                ),
                if (!_loadingBanks && _banks.isNotEmpty)
                  Icon(
                    Icons.search,
                    color: _selectedBank != null
                        ? Colors.deepOrangeAccent
                        : Colors.white38,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),

        // Hidden FormField for validation wiring
        FormField<Map<String, dynamic>>(
          initialValue: _selectedBank,
          validator: (_) =>
              _selectedBank == null ? 'Please select a bank' : null,
          builder: (field) => field.errorText != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    field.errorText!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // ── Account number field ───────────────────────────────────────────────────

  Widget _buildAccountNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Number',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141433),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Enter account number',
              hintStyle: TextStyle(color: Colors.white30),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              errorStyle: TextStyle(color: Colors.redAccent),
            ),
            onChanged: _onAccountNumberChanged,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter account number';
              if (v.length < _kNubanLength)
                return 'Enter a valid account number';
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Account name field (read-only, auto-populated) ─────────────────────────

  Widget _buildAccountNameField() {
    final isResolving = _resolvingAccountName;
    final hasError = _accountNameError != null;
    final hasName = _accountNameController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account Name',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141433),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError
                  ? Colors.redAccent.withOpacity(0.5)
                  : hasName
                  ? Colors.greenAccent.withOpacity(0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _accountNameController,
                  readOnly: true,
                  style: TextStyle(
                    color: hasName ? Colors.greenAccent : Colors.white38,
                    fontStyle: hasName ? FontStyle.normal : FontStyle.italic,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: isResolving
                        ? 'Verifying…'
                        : 'Auto-filled from your bank',
                    hintStyle: TextStyle(
                      color: isResolving ? Colors.white54 : Colors.white30,
                      fontStyle: FontStyle.italic,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (_) {
                    if (_selectedMethod != _PaymentMethod.flutterwave)
                      return null;
                    if (_accountNameController.text.trim().isEmpty) {
                      return 'Account name could not be verified';
                    }
                    return null;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: isResolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.deepOrangeAccent,
                          ),
                        ),
                      )
                    : hasName
                    ? const Icon(
                        Icons.verified,
                        color: Colors.greenAccent,
                        size: 20,
                      )
                    : hasError
                    ? const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 20,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _accountNameError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCountryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Country',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141433),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedCountry,
            items: _countries
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c, style: const TextStyle(color: Colors.white)),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _selectedCountry = val;
                _selectedBank = null;
                _accountNameController.clear();
                _accountNameError = null;
              });
              _fetchBanks(val);

              // Trigger FX preview when country changes
              final dollars =
                  double.tryParse(_amountController.text.trim()) ?? 0.0;
              if (dollars >= 100) {
                context.read<WithdrawalCubit>().loadFxPreview(
                  amountUsd: dollars,
                  country: val,
                );
              }
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            dropdownColor: const Color(0xFF1C1533),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── PayPal form ────────────────────────────────────────────────────────────

  Widget _buildPayPalForm() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF003087).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF003087).withOpacity(0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF009CDE), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Funds will be sent to your PayPal account in USD. '
                  'Make sure your PayPal account is verified.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildInputField(
          label: 'PayPal Email Address',
          hint: 'your@paypal.com',
          controller: _paypalEmailController,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter your PayPal email';
            if (!RegExp(
              r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$',
            ).hasMatch(v.trim())) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
        _buildInputField(
          label: 'Confirm PayPal Email',
          hint: 'Re-enter your PayPal email',
          controller: _paypalEmailConfirmController,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.isEmpty)
              return 'Please confirm your PayPal email';
            if (v.trim() != _paypalEmailController.text.trim()) {
              return 'Emails do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ── Generic input field ────────────────────────────────────────────────────

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141433),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              errorStyle: const TextStyle(color: Colors.redAccent),
            ),
            validator: validator,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Submit loading banner ──────────────────────────────────────────────────

  Widget _buildSubmittingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: const Color(0xFF1C1533),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.deepOrangeAccent),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _selectedMethod == _PaymentMethod.paypal
                ? 'Sending to PayPal…'
                : 'Processing bank transfer…',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060522),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Request Withdrawal'),
        centerTitle: true,
      ),
      body: BlocConsumer<WithdrawalCubit, WithdrawalState>(
        listener: (ctx, state) {
          if (state is WithdrawalSuccess) {
            _showSuccessDialog(state.transactionData);
          } else if (state is WithdrawalError) {
            _showErrorDialog(
              state.message,
              retryable: !_isPinNotSet(state.message),
            );
          } else if (state is WithdrawalBalanceLoaded) {
            setState(() => _withdrawableCents = state.balance);
          } else if (state is WithdrawalAccountNameLoaded) {
            setState(() {
              _accountNameController.text = state.accountName;
              _resolvingAccountName = false;
              _accountNameError = null;
            });
          } else if (state is WithdrawalAccountNameError) {
            setState(() {
              _accountNameController.clear();
              _resolvingAccountName = false;
              _accountNameError = state.message;
            });
          } else if (state is WithdrawalAccountNameLoading) {
            setState(() {
              _resolvingAccountName = true;
              _accountNameError = null;
            });
          }
        },
        builder: (ctx, state) {
          _isSubmitting = state is WithdrawalSubmitting;

          if (state is WithdrawalBalanceLoaded) {
            _withdrawableCents = state.balance;
          }

          if (state is WithdrawalLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.deepOrangeAccent),
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _buildBalanceCard(),
                _buildMethodSelector(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildAmountField(),
                      if (_selectedMethod == _PaymentMethod.flutterwave)
                        _buildFlutterwaveForm()
                      else
                        _buildPayPalForm(),
                      _buildInputField(
                        label: 'Reason (Optional)',
                        controller: _reasonController,
                        maxLines: 3,
                        validator: (_) => null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),

      // ── Bottom bar ─────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress banner — slides in while request is in flight
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isSubmitting
                  ? _buildSubmittingBanner()
                  : const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _onProceedToPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrangeAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.deepOrangeAccent.withOpacity(
                    0.5,
                  ),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Processing…',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Proceed to Withdraw',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bank search bottom sheet  (self-contained, stateful)
// ─────────────────────────────────────────────────────────────────────────────

class _BankSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> banks;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _BankSearchSheet({
    required this.banks,
    required this.onSelected,
    Key? key,
  }) : super(key: key);

  @override
  State<_BankSearchSheet> createState() => _BankSearchSheetState();
}

class _BankSearchSheetState extends State<_BankSearchSheet> {
  final _searchCtrl = TextEditingController();
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.of(widget.banks);
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(widget.banks)
          : widget.banks
                .where(
                  (b) =>
                      (b['name']?.toString() ?? '').toLowerCase().contains(q),
                )
                .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_filter)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Select Bank',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141433),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search bank name…',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white38,
                    size: 20,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Result count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filtered.length} bank${_filtered.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Results list
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No banks match your search.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final bank = _filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          bank['name']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white24,
                          size: 18,
                        ),
                        onTap: () => widget.onSelected(bank),
                      );
                    },
                  ),
          ),

          // Keyboard clearance
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment method selector card
// ─────────────────────────────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.accentColor,
    required this.selected,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withOpacity(0.15)
              : const Color(0xFF141433),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accentColor : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: selected ? accentColor : Colors.white38,
                  size: 22,
                ),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle, color: accentColor, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                color: selected
                    ? accentColor.withOpacity(0.85)
                    : Colors.white30,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FX Preview Widget - shows estimated local currency amount
// ─────────────────────────────────────────────────────────────────────────────

class _FxPreviewWidget extends StatelessWidget {
  final double amountUsd;
  final String country;
  final bool enabled;

  const _FxPreviewWidget({
    required this.amountUsd,
    required this.country,
    required this.enabled,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WithdrawalCubit, WithdrawalState>(
      builder: (ctx, state) {
        // Don't show preview if amount is less than minimum or method is PayPal
        if (!enabled || amountUsd < 100) {
          return const SizedBox.shrink();
        }

        if (state is WithdrawalFxPreviewLoading) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.deepOrangeAccent),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Fetching exchange rate...',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          );
        }

        if (state is WithdrawalFxPreviewLoaded) {
          final localAmountFormatted = _formatLocalAmount(
            state.localAmount,
            state.localCurrency,
          );

          return Container(
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.deepOrangeAccent.withOpacity(0.15),
                  Colors.deepPurple.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.deepOrangeAccent.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.currency_exchange,
                      color: Colors.deepOrangeAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'You will receive approximately:',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  localAmountFormatted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rate: 1 USD = ${state.rate.toStringAsFixed(2)} ${state.localCurrency}',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  state.note,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          );
        }

        if (state is WithdrawalFxPreviewError && state.message.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orangeAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.message,
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  String _formatLocalAmount(double amount, String currencyCode) {
    final symbol = _getCurrencySymbol(currencyCode);
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
      name:
          currencyCode, // 'name' is used for the currency code (e.g., 'USD', 'NGN')
    );
    return formatter.format(amount);
  }

  String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'NGN':
        return '₦';
      case 'GHS':
        return '₵';
      case 'KES':
        return 'KSh';
      case 'ZAR':
        return 'R';
      case 'UGX':
        return 'USh';
      case 'TZS':
        return 'TSh';
      case 'XAF':
      case 'XOF':
        return 'CFA';
      default:
        return currencyCode;
    }
  }

  // String _getCurrencySymbol(String currencyCode) {
  //   switch (currencyCode.toUpperCase()) {
  //     case 'NGN':
  //       return '₦';
  //     case 'GHS':
  //       return '₵';
  //     case 'KES':
  //       return 'KSh';
  //     case 'ZAR':
  //       return 'R';
  //     case 'UGX':
  //       return 'USh';
  //     case 'TZS':
  //       return 'TSh';
  //     case 'XAF':
  //     case 'XOF':
  //       return 'CFA';
  //     default:
  //       return currencyCode;
  //   }
  // }
}
