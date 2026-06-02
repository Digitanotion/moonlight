// lib/features/clubs/presentation/pages/club_treasury_payout_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/data/datasources/club_treasury_remote_data_source.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_treasury_cubit.dart';
import 'package:moonlight/widgets/top_snack.dart';

class ClubTreasuryPayoutProfileScreen extends StatefulWidget {
  final String clubUuid;

  const ClubTreasuryPayoutProfileScreen({super.key, required this.clubUuid});

  @override
  State<ClubTreasuryPayoutProfileScreen> createState() =>
      _ClubTreasuryPayoutProfileScreenState();
}

class _ClubTreasuryPayoutProfileScreenState
    extends State<ClubTreasuryPayoutProfileScreen> {
  String _method = 'flutterwave';
  String _country = 'Nigeria';

  final _bankAccountNameCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankCodeCtrl = TextEditingController();
  final _paypalEmailCtrl = TextEditingController();

  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _selectedBank;
  bool _loadingBanks = false;
  bool _isResolvingName = false;
  String? _resolvedName;

  static const _countries = [
    'Nigeria',
    'Ghana',
    'Kenya',
    'Uganda',
    'Tanzania',
    'Rwanda',
    'South Africa',
    'UK',
    'US',
  ];

  @override
  void initState() {
    super.initState();
    _bankAccountNumberCtrl.addListener(_onAccountNumberChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBanks());
  }

  @override
  void dispose() {
    _bankAccountNameCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankCodeCtrl.dispose();
    _paypalEmailCtrl.dispose();
    super.dispose();
  }

  void _onAccountNumberChanged() {
    final code = _selectedBank?['code'] as String?;
    final num = _bankAccountNumberCtrl.text;
    if (num.length >= 8 && code != null) _resolveAccountName(num, code);
  }

  Future<void> _loadBanks() async {
    if (_method != 'flutterwave') return;
    setState(() => _loadingBanks = true);
    try {
      final ds = context.read<ClubTreasuryRemoteDataSource>();
      final dio = (ds as dynamic).dio;
      final res = await dio.get(
        '/api/v1/wallet/banks',
        queryParameters: {'country': _country},
      );
      setState(() {
        _banks = List<Map<String, dynamic>>.from(res.data['data'] ?? []);
        _loadingBanks = false;
      });
    } catch (_) {
      setState(() => _loadingBanks = false);
    }
  }

  Future<void> _resolveAccountName(String number, String code) async {
    setState(() {
      _isResolvingName = true;
      _resolvedName = null;
    });
    try {
      final ds = context.read<ClubTreasuryRemoteDataSource>();
      final dio = (ds as dynamic).dio;
      final res = await dio.get(
        '/api/v1/wallet/resolve-account',
        queryParameters: {'account_number': number, 'bank_code': code},
      );
      final name = res.data['account_name'] as String?;
      setState(() {
        _resolvedName = name;
        _bankAccountNameCtrl.text = name ?? '';
        _isResolvingName = false;
      });
    } catch (_) {
      setState(() => _isResolvingName = false);
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
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _InfoBanner(),
                          const SizedBox(height: 20),
                          _SectionLabel('Default Payout Method'),
                          const SizedBox(height: 10),
                          _MethodToggle(
                            selected: _method,
                            onChanged: (v) {
                              setState(() => _method = v);
                              if (v == 'flutterwave') _loadBanks();
                            },
                          ),
                          const SizedBox(height: 20),
                          if (_method == 'flutterwave') ...[
                            _SectionLabel('Default Bank Details'),
                            const SizedBox(height: 10),
                            _CountryDropdown(
                              value: _country,
                              countries: _countries,
                              onChanged: (v) {
                                setState(() => _country = v!);
                                _loadBanks();
                              },
                            ),
                            const SizedBox(height: 12),
                            _BankDropdown(
                              banks: _banks,
                              selected: _selectedBank,
                              loading: _loadingBanks,
                              onChanged: (b) {
                                setState(() {
                                  _selectedBank = b;
                                  _bankNameCtrl.text = b?['name'] ?? '';
                                  _bankCodeCtrl.text = b?['code'] ?? '';
                                });
                                final num = _bankAccountNumberCtrl.text;
                                if (num.length >= 8 && b != null) {
                                  _resolveAccountName(num, b['code']);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            _InputField(
                              controller: _bankAccountNumberCtrl,
                              label: 'Account Number',
                              hint: 'Enter account number',
                              keyboardType: TextInputType.number,
                              maxLength: 20,
                              suffix: _isResolvingName
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
                            const SizedBox(height: 12),
                            _InputField(
                              controller: _bankAccountNameCtrl,
                              label: 'Account Name',
                              hint: 'Auto-filled or enter manually',
                            ),
                          ] else ...[
                            _SectionLabel('Default PayPal'),
                            const SizedBox(height: 10),
                            _InputField(
                              controller: _paypalEmailCtrl,
                              label: 'PayPal Email',
                              hint: 'your@paypal.com',
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ],
                          const SizedBox(height: 32),
                          _SubmitButton(
                            submitting: state.submitting,
                            onTap: () => _submit(context),
                          ),
                          const SizedBox(height: 40),
                        ],
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

  void _submit(BuildContext context) {
    if (_method == 'flutterwave') {
      if (_bankAccountNumberCtrl.text.trim().isEmpty ||
          _bankAccountNameCtrl.text.trim().isEmpty ||
          _selectedBank == null) {
        TopSnack.error(context, 'Please fill in all bank details.');
        return;
      }
    } else {
      if (_paypalEmailCtrl.text.trim().isEmpty) {
        TopSnack.error(context, 'Please enter a PayPal email.');
        return;
      }
    }

    final data = <String, dynamic>{'default_payout_method': _method};

    if (_method == 'flutterwave') {
      data['default_bank_account_name'] = _bankAccountNameCtrl.text.trim();
      data['default_bank_account_number'] = _bankAccountNumberCtrl.text.trim();
      data['default_bank_name'] = _bankNameCtrl.text.trim();
      data['default_bank_code'] = _bankCodeCtrl.text.trim();
      data['default_bank_country'] = _country;
    } else {
      data['default_paypal_email'] = _paypalEmailCtrl.text.trim();
    }

    context.read<ClubTreasuryCubit>().updatePayoutProfile(data);
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
          const Text(
            'Default Payout Account',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.blueAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Set a default payout account for quick withdrawals. '
              'Admins can still override this per-request.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MethodToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _MethodToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToggleChip(
          label: 'Bank Transfer',
          icon: Icons.account_balance_rounded,
          active: selected == 'flutterwave',
          onTap: () => onChanged('flutterwave'),
        ),
        const SizedBox(width: 12),
        _ToggleChip(
          label: 'PayPal',
          icon: Icons.payment_rounded,
          active: selected == 'paypal',
          onTap: () => onChanged('paypal'),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.active,
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
            color: active
                ? const Color(0xFFFF7A00).withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? const Color(0xFFFF7A00)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: active ? const Color(0xFFFF7A00) : Colors.white38,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? const Color(0xFFFF7A00) : Colors.white38,
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

class _CountryDropdown extends StatelessWidget {
  final String value;
  final List<String> countries;
  final ValueChanged<String?> onChanged;
  const _CountryDropdown({
    required this.value,
    required this.countries,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1A1040),
          style: const TextStyle(color: Colors.white),
          items: countries
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _BankDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> banks;
  final Map<String, dynamic>? selected;
  final bool loading;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  const _BankDropdown({
    required this.banks,
    required this.selected,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: selected,
          isExpanded: true,
          hint: const Text(
            'Select Bank',
            style: TextStyle(color: Colors.white54),
          ),
          dropdownColor: const Color(0xFF1A1040),
          style: const TextStyle(color: Colors.white),
          items: banks
              .map(
                (b) => DropdownMenuItem(value: b, child: Text(b['name'] ?? '')),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final int? maxLength;
  final Widget? suffix;
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLength,
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
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
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
          ),
        ),
      ],
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

class _SubmitButton extends StatelessWidget {
  final bool submitting;
  final VoidCallback onTap;
  const _SubmitButton({required this.submitting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: submitting ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF7A00),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Save Payout Profile',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }
}
