// lib/features/clubs/presentation/pages/club_withdrawal_request_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/domain/entities/club_treasury.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_treasury_cubit.dart';
import 'package:moonlight/features/clubs/data/datasources/club_treasury_remote_data_source.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:uuid/uuid.dart';

// ── Country list (matches Flutterwave payout docs) ────────────────────────
// Kept in sync with withdrawal_page.dart's _kSupportedCountries.
class _CountryInfo {
  final String name;
  final String currency;
  const _CountryInfo(this.name, this.currency);
}

const List<_CountryInfo> _kCountries = [
  _CountryInfo('Nigeria', 'NGN'),
  _CountryInfo('Ghana', 'GHS'),
  _CountryInfo('Kenya', 'KES'),
  _CountryInfo('South Africa', 'ZAR'),
  _CountryInfo('Uganda', 'UGX'),
  _CountryInfo('Tanzania', 'TZS'),
  _CountryInfo('Rwanda', 'RWF'),
  _CountryInfo('Zambia', 'ZMW'),
  _CountryInfo('Cameroon', 'XAF'),
  _CountryInfo('Chad', 'XAF'),
  _CountryInfo('Congo', 'XAF'),
  _CountryInfo('Gabon', 'XAF'),
  _CountryInfo('Senegal', 'XOF'),
  _CountryInfo('Ivory Coast', 'XOF'),
  _CountryInfo('Malawi', 'MWK'),
  _CountryInfo('Sierra Leone', 'SLL'),
  _CountryInfo('Ethiopia', 'ETB'),
  _CountryInfo('Austria', 'EUR'),
  _CountryInfo('Belgium', 'EUR'),
  _CountryInfo('Bulgaria', 'EUR'),
  _CountryInfo('Croatia', 'EUR'),
  _CountryInfo('Cyprus', 'EUR'),
  _CountryInfo('Czech Republic', 'EUR'),
  _CountryInfo('Denmark', 'EUR'),
  _CountryInfo('Estonia', 'EUR'),
  _CountryInfo('Finland', 'EUR'),
  _CountryInfo('Germany', 'EUR'),
  _CountryInfo('Greece', 'EUR'),
  _CountryInfo('Hungary', 'EUR'),
  _CountryInfo('Ireland', 'EUR'),
  _CountryInfo('Italy', 'EUR'),
  _CountryInfo('Latvia', 'EUR'),
  _CountryInfo('Lithuania', 'EUR'),
  _CountryInfo('Luxembourg', 'EUR'),
  _CountryInfo('Malta', 'EUR'),
  _CountryInfo('Netherlands', 'EUR'),
  _CountryInfo('Poland', 'EUR'),
  _CountryInfo('Slovakia', 'EUR'),
  _CountryInfo('Slovenia', 'EUR'),
  _CountryInfo('Spain', 'EUR'),
  _CountryInfo('Sweden', 'EUR'),
  _CountryInfo('UK', 'GBP'),
  _CountryInfo('US', 'USD'),
  _CountryInfo('Australia', 'AUD'),
  _CountryInfo('India', 'INR'),
  _CountryInfo('UAE', 'AED'),
];

class ClubWithdrawalRequestScreen extends StatefulWidget {
  final String clubUuid;
  final String clubName;
  final ClubTreasurySummary summary;

  const ClubWithdrawalRequestScreen({
    super.key,
    required this.clubUuid,
    required this.clubName,
    required this.summary,
  });

  @override
  State<ClubWithdrawalRequestScreen> createState() =>
      _ClubWithdrawalRequestScreenState();
}

class _ClubWithdrawalRequestScreenState
    extends State<ClubWithdrawalRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();
  final _bankAccountNameCtrl = TextEditingController();
  final _paypalEmailCtrl = TextEditingController();
  final _paypalEmailConfirmCtrl = TextEditingController();

  String _method = 'flutterwave';
  String _country = 'Nigeria';
  bool _obscurePin = true;

  List<Map<String, dynamic>> _banks = [];
  bool _loadingBanks = false;
  Map<String, dynamic>? _selectedBank;

  bool _resolvingName = false;
  String? _resolvedName;

  @override
  void initState() {
    super.initState();
    _bankAccountNumberCtrl.addListener(_onAccountNumberChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBanks());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    _pinCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    _bankAccountNameCtrl.dispose();
    _paypalEmailCtrl.dispose();
    _paypalEmailConfirmCtrl.dispose();
    super.dispose();
  }

  void _onAccountNumberChanged() {
    final code = _selectedBank?['code'] as String?;
    final num = _bankAccountNumberCtrl.text;
    if (num.length >= 8 && code != null) _resolveAccountName(num, code);
  }

  dynamic get _dio =>
      (context.read<ClubTreasuryRemoteDataSource>() as dynamic).dio;

  Future<void> _loadBanks() async {
    if (_method != 'flutterwave') return;
    setState(() {
      _loadingBanks = true;
      _banks = [];
      _selectedBank = null;
      _resolvedName = null;
      _bankAccountNameCtrl.clear();
    });
    try {
      final res = await _dio.get(
        '/api/v1/wallet/banks',
        queryParameters: {'country': _country},
      );
      if (mounted) {
        setState(() {
          _banks = List<Map<String, dynamic>>.from(res.data['data'] ?? []);
          _loadingBanks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  Future<void> _resolveAccountName(String number, String code) async {
    setState(() {
      _resolvingName = true;
      _resolvedName = null;
    });
    try {
      final res = await _dio.get(
        '/api/v1/wallet/resolve-account',
        queryParameters: {'account_number': number, 'bank_code': code},
      );
      final name = res.data['account_name'] as String?;
      if (mounted) {
        setState(() {
          _resolvedName = name;
          _bankAccountNameCtrl.text = name ?? '';
          _resolvingName = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _resolvingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ClubTreasuryCubit(
        ctx.read<ClubTreasuryRemoteDataSource>(),
        widget.clubUuid,
      ),
      child: BlocConsumer<ClubTreasuryCubit, ClubTreasuryState>(
        listener: (context, state) {
          if (state.error != null) {
            TopSnack.error(context, state.error!);
            context.read<ClubTreasuryCubit>().clearMessages();
          }
          if (state.success != null) {
            TopSnack.success(context, state.success!);
            context.read<ClubTreasuryCubit>().clearMessages();
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
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
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            _AvailableChip(summary: widget.summary),
                            const SizedBox(height: 20),

                            // ── Amount ────────────────────────────────
                            _SectionLabel('Withdrawal Amount (USD)'),
                            const SizedBox(height: 8),
                            _buildAmountField(), // ← RESTORED
                            const SizedBox(height: 20),

                            // ── Payment method ────────────────────────
                            _SectionLabel('Payment Method'),
                            const SizedBox(height: 8),
                            _buildMethodToggle(),
                            const SizedBox(height: 20),

                            // ── Bank / PayPal details ─────────────────
                            if (_method == 'flutterwave') ...[
                              _SectionLabel('Bank Details'),
                              const SizedBox(height: 8),
                              _buildCountryDropdown(),
                              const SizedBox(height: 12),
                              _buildBankDropdown(),
                              const SizedBox(height: 12),
                              _InputField(
                                controller: _bankAccountNumberCtrl,
                                label: 'Account Number',
                                hint: 'Enter account number',
                                keyboardType: TextInputType.number,
                                maxLength: 20,
                                required: true,
                                suffix: _resolvingName
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white54,
                                        ),
                                      )
                                    : null,
                              ),
                              if (_resolvedName != null) ...[
                                const SizedBox(height: 8),
                                _ResolvedNameBadge(name: _resolvedName!),
                              ],
                            ] else ...[
                              _SectionLabel('PayPal Details'),
                              const SizedBox(height: 8),
                              _InputField(
                                controller: _paypalEmailCtrl,
                                label: 'PayPal Email',
                                hint: 'your@paypal.com',
                                keyboardType: TextInputType.emailAddress,
                                required: true,
                              ),
                              const SizedBox(height: 12),
                              _InputField(
                                controller: _paypalEmailConfirmCtrl,
                                label: 'Confirm PayPal Email',
                                hint: 'Re-enter PayPal email',
                                keyboardType: TextInputType.emailAddress,
                                required: true,
                              ),
                            ],

                            const SizedBox(height: 20),

                            // ── Reason ────────────────────────────────
                            _SectionLabel('Purpose / Reason'),
                            const SizedBox(height: 8),
                            _InputField(
                              controller: _reasonCtrl,
                              label: 'Reason',
                              hint: 'e.g. Monthly club expenses, event costs…',
                              maxLines: 3,
                              maxLength: 500,
                              required: true,
                            ),

                            const SizedBox(height: 20),

                            // ── Treasury PIN ──────────────────────────
                            _SectionLabel('Club Treasury PIN'),
                            const SizedBox(height: 8),
                            _buildPinField(),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.2),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.security_rounded,
                                    color: Colors.blueAccent,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Your 6-digit club treasury PIN is required to submit. '
                                      'Other admins will be notified to approve.',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: state.submitting
                                    ? null
                                    : () => _submit(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF7A00),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: state.submitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.arrow_upward_rounded),
                                          SizedBox(width: 8),
                                          Text(
                                            'Submit Withdrawal Request',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request Withdrawal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.clubName,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Amount field (was commented out — now live) ──────────────────────────
  Widget _buildAmountField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(
              '\$',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 24,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
              ),
              validator: (v) {
                final amt = double.tryParse(v ?? '');
                if (amt == null || amt <= 0) {
                  return 'Enter a valid amount';
                }
                if (amt > widget.summary.usdAvailable) {
                  return 'Exceeds available balance '
                      '(\$${widget.summary.usdAvailable.toStringAsFixed(2)})';
                }
                return null;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'USD',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodToggle() {
    return Row(
      children: [
        _MethodChip(
          label: 'Bank Transfer',
          icon: Icons.account_balance_rounded,
          selected: _method == 'flutterwave',
          onTap: () {
            setState(() => _method = 'flutterwave');
            _loadBanks();
          },
        ),
        const SizedBox(width: 12),
        _MethodChip(
          label: 'PayPal',
          icon: Icons.payment_rounded,
          selected: _method == 'paypal',
          onTap: () => TopSnack.info(
            context,
            'PayPal payment is not available currently',
          ),
        ),
      ],
    );
  }

  // ── Country dropdown — now uses full _kCountries list ────────────────────
  Widget _buildCountryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _country,
          dropdownColor: const Color(0xFF1A1040),
          style: const TextStyle(color: Colors.white),
          isExpanded: true,
          items: _kCountries
              .map(
                (c) => DropdownMenuItem(
                  value: c.name,
                  child: Text('${c.name}  (${c.currency})'),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null || v == _country) return;
            setState(() => _country = v);
            _loadBanks(); // ← re-fetches banks for the new country
          },
        ),
      ),
    );
  }

  Widget _buildBankDropdown() {
    if (_loadingBanks) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(
            color: Colors.white54,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final sortedBanks = List<Map<String, dynamic>>.from(_banks)
      ..sort(
        (a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''),
      );

    return GestureDetector(
      onTap: _banks.isEmpty
          ? null
          : () async {
              final picked = await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _BankPickerSheet(banks: sortedBanks),
              );
              if (picked != null) {
                setState(() => _selectedBank = picked);
                final num = _bankAccountNumberCtrl.text;
                if (num.length >= 8) {
                  _resolveAccountName(num, picked['code'] as String);
                }
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selectedBank != null
                ? const Color(0xFFFF7A00).withOpacity(0.5)
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance_rounded,
              color: Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _banks.isEmpty
                    ? 'No banks available for this country'
                    : (_selectedBank != null
                          ? (_selectedBank!['name'] as String? ??
                                'Unknown Bank')
                          : 'Select Bank'),
                style: TextStyle(
                  color: _selectedBank != null ? Colors.white : Colors.white38,
                  fontSize: 15,
                  fontWeight: _selectedBank != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: TextFormField(
        controller: _pinCtrl,
        obscureText: _obscurePin,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          letterSpacing: 8,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: '••••••',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 22,
            letterSpacing: 8,
          ),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: const Icon(Icons.lock_rounded, color: Colors.white54),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePin
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: Colors.white54,
            ),
            onPressed: () => setState(() => _obscurePin = !_obscurePin),
          ),
        ),
        validator: (v) {
          if (v == null || v.length != 6) {
            return 'Enter your 6-digit treasury PIN';
          }
          return null;
        },
      ),
    );
  }

  void _submit(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_method == 'paypal' &&
        _paypalEmailCtrl.text.trim() != _paypalEmailConfirmCtrl.text.trim()) {
      TopSnack.error(context, 'PayPal email addresses do not match.');
      return;
    }

    if (_method == 'flutterwave') {
      if (_selectedBank == null) {
        TopSnack.error(context, 'Please select a bank.');
        return;
      }
      if (_resolvingName) {
        TopSnack.error(context, 'Still verifying account — please wait.');
        return;
      }
    }

    final data = <String, dynamic>{
      'amount_usd': double.parse(_amountCtrl.text),
      'payment_method': _method,
      'reason': _reasonCtrl.text.trim(),
      'pin': _pinCtrl.text.trim(),
      'idempotency_key': const Uuid().v4(),
    };

    if (_method == 'flutterwave') {
      data['bank_account_name'] = _bankAccountNameCtrl.text.trim();
      data['bank_account_number'] = _bankAccountNumberCtrl.text.trim();
      data['bank_name'] = _selectedBank!['name'];
      data['bank_code'] = _selectedBank!['code'];
      data['bank_country'] = _country;
    } else {
      data['paypal_email'] = _paypalEmailCtrl.text.trim();
    }

    context.read<ClubTreasuryCubit>().submitRequest(data);
  }
}

// ── Support widgets (unchanged from original) ─────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _AvailableChip extends StatelessWidget {
  final ClubTreasurySummary summary;
  const _AvailableChip({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.greenAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          const Text(
            'Available to withdraw',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const Spacer(),
          Text(
            '\$${summary.usdAvailable.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolvedNameBadge extends StatelessWidget {
  final String name;
  const _ResolvedNameBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool required;
  final Widget? suffix;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.maxLength,
    this.required = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
              ),
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: suffix != null
                  ? Padding(padding: const EdgeInsets.all(12), child: suffix)
                  : null,
            ),
            validator: required
                ? (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null
                : null,
          ),
        ),
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFF7A00).withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFF7A00)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFFFF7A00) : Colors.white38,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFFFF7A00) : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bank picker sheet (identical to original) ─────────────────────────────

class _BankPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> banks;
  const _BankPickerSheet({required this.banks});

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.banks;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? widget.banks
          : widget.banks
                .where(
                  (b) => (b['name'] as String? ?? '').toLowerCase().contains(q),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Select Bank',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.banks.length} banks',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search banks…',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white38,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearch();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          color: Colors.white.withOpacity(0.2),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No banks found',
                          style: TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final bank = _filtered[index];
                      final name = bank['name'] as String? ?? '';
                      final code = bank['code'] as String? ?? '';
                      final query = _searchCtrl.text.trim();
                      return InkWell(
                        onTap: () => Navigator.pop(context, bank),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1040),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Color(0xFFFF7A00),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _HighlightedText(text: name, query: query),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Code: $code',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white24,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);
    if (matchIndex < 0) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    final before = text.substring(0, matchIndex);
    final matched = text.substring(matchIndex, matchIndex + query.length);
    final after = text.substring(matchIndex + query.length);
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: matched,
            style: const TextStyle(
              color: Color(0xFFFF7A00),
              fontWeight: FontWeight.w800,
              backgroundColor: Color(0x22FF7A00),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}
