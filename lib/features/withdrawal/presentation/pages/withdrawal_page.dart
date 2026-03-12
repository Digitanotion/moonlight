// lib/features/withdrawal/presentation/pages/withdrawal_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/utils/formatting.dart';
import '../cubit/withdrawal_cubit.dart';
import 'withdrawal_pin_page.dart';

class WithdrawalPage extends StatefulWidget {
  const WithdrawalPage({Key? key}) : super(key: key);

  @override
  State<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends State<WithdrawalPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController =
      TextEditingController(); // user types dollars e.g. "150"
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _swiftCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isSubmitting = false;
  bool _loadingBanks = false;

  // ✅ Stored locally so the validator always has the latest value.
  // The API returns withdrawable_cents (already in cents); coin * 0.005 = USD
  // so coin * 0.5 = cents. The server stores the pre-calculated cents value.
  int _withdrawableCents = 0;

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

  // ── Computed ───────────────────────────────────────────────────────────

  /// What the user typed as a dollar amount
  double get _enteredDollars =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  /// Entered dollars → cents (sent to API)
  int get _enteredCents => (_enteredDollars * 100).round();

  /// Withdrawable balance in USD (display only)
  double get _withdrawableDollars => _withdrawableCents / 100.0;

  // ── Lifecycle ──────────────────────────────────────────────────────────

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
    _amountController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _swiftCodeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // ── Bank fetch ─────────────────────────────────────────────────────────

  Future<void> _fetchBanks(String country) async {
    setState(() {
      _loadingBanks = true;
      _selectedBank = null;
      _banks = [];
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

  // ── PIN-not-set detection (mirrors pin page) ───────────────────────────

  bool _isPinNotSet(String msg) {
    final s = msg.toLowerCase();
    return s.contains('no pin') ||
        s.contains('pin not set') ||
        s.contains('No PIN set') ||
        s.contains('Please set a wallet PIN') ||
        s.isEmpty;
  }

  // ── Dialogs ────────────────────────────────────────────────────────────

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
    final flwStatus = (data['data']?['flw_status'] ?? 'pending')
        .toString()
        .toUpperCase();

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
              '\$${_enteredDollars.toStringAsFixed(2)} is being transferred to '
              '${_accountNameController.text}'
              '${_selectedBank != null ? " — ${_selectedBank!['name']}" : ""}.',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Status: $flwStatus',
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
    // Intercept PIN-not-set before showing generic error
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

  // ── Submit ─────────────────────────────────────────────────────────────

  Future<void> _submitWithdrawal(String pin) async {
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

  void _onProceedToPin() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBank == null) {
      _showErrorDialog('Please select your bank.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WithdrawalPinPage(
          amountUsdCents: _enteredCents,
          bankAccountName: _accountNameController.text.trim(),
          // ✅ async callback — pin page awaits this and catches errors
          onPinVerified: (pin) async {
            Navigator.pop(context); // dismiss pin page first
            await _submitWithdrawal(pin);
          },
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────

  Widget _buildBalanceCard() {
    // withdrawable_cents already represents earnings in cents (coin * 0.5).
    // Display as dollars: cents / 100.
    final dollars = _withdrawableDollars;
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
            formatusd(dollars),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Powered by Flutterwave — instant transfer',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Minimum: \$100.00',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Amount field — user enters dollars (e.g. "150"), not cents
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
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter an amount';
                    final dollars = double.tryParse(v) ?? 0.0;
                    final cents = (dollars * 100).round();
                    if (cents < 10000) {
                      return 'Minimum withdrawal is \$100.00';
                    }
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
              });
              _fetchBanks(val);
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

  Widget _buildBankDropdown() {
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
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141433),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _loadingBanks
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
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
                  ),
                )
              : _banks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
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
                          style: TextStyle(color: Colors.deepOrangeAccent),
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedBank,
                  isExpanded: true,
                  hint: const Text(
                    'Select your bank',
                    style: TextStyle(color: Colors.white38),
                  ),
                  items: _banks.map((bank) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: bank,
                      child: Text(
                        bank['name']?.toString() ?? '',
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedBank = val),
                  validator: (_) =>
                      _selectedBank == null ? 'Please select a bank' : null,
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

  // ── Build ──────────────────────────────────────────────────────────────

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
            // ✅ PIN-not-set is intercepted inside _showErrorDialog
            _showErrorDialog(
              state.message,
              retryable: !_isPinNotSet(state.message),
            );
          } else if (state is WithdrawalBalanceLoaded) {
            // ✅ Capture balance in listener so it's always up-to-date
            setState(() => _withdrawableCents = state.balance);
          }
        },
        builder: (ctx, state) {
          _isSubmitting = state is WithdrawalSubmitting;

          // Also sync in builder for first paint
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

                // Flutterwave badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5A623).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFF5A623).withOpacity(0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flash_on,
                              color: Color(0xFFF5A623),
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Instant transfer via Flutterwave',
                              style: TextStyle(
                                color: Color(0xFFF5A623),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildAmountField(), // ← dollars input
                      _buildCountryDropdown(),
                      _buildBankDropdown(),
                      _buildInputField(
                        label: 'Account Name',
                        hint: 'Exactly as registered with your bank',
                        controller: _accountNameController,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter account name'
                            : null,
                      ),
                      _buildInputField(
                        label: 'Account Number',
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Enter account number';
                          }
                          if (v.length < 8) {
                            return 'Enter a valid account number';
                          }
                          return null;
                        },
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _onProceedToPin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrangeAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.deepOrangeAccent.withOpacity(0.5),
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text(
                    'Proceed to Withdraw',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
