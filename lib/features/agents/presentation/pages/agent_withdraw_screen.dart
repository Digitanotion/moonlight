// Agent commission withdrawal: coins -> USD at the server's rate, paid
// manually after admin review. Country is part of the payout details.

import 'package:flutter/material.dart';
import 'package:moonlight/core/constants/flutterwave_countries.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/agents/data/agent_remote_data_source.dart';
import 'package:moonlight/features/agents/presentation/pages/agent_ui.dart';
import 'package:moonlight/features/withdrawal/domain/repositories/withdrawal_repository.dart';
import 'package:moonlight/widgets/top_snack.dart';

class AgentWithdrawScreen extends StatefulWidget {
  final int balanceCoins;
  final double usdPerCoin;
  final int minCoins;
  const AgentWithdrawScreen({
    super.key,
    required this.balanceCoins,
    required this.usdPerCoin,
    required this.minCoins,
  });

  @override
  State<AgentWithdrawScreen> createState() => _AgentWithdrawScreenState();
}

class _AgentWithdrawScreenState extends State<AgentWithdrawScreen> {
  final _coins = TextEditingController();
  final _accNo = TextEditingController();
  final _accName = TextEditingController();
  final _paypal = TextEditingController();
  String _method = 'flutterwave';
  String _country = 'Nigeria';
  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _bank;
  bool _loadingBanks = false;
  bool _busy = false;
  // One key per screen visit: a double-tap or retry can't create two requests.
  final String _idem = DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _coins.text = widget.balanceCoins.toString();
    _loadBanks();
  }

  @override
  void dispose() {
    _coins.dispose();
    _accNo.dispose();
    _accName.dispose();
    _paypal.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    setState(() {
      _loadingBanks = true;
      _bank = null;
      _banks = [];
    });
    try {
      final b = await sl<WithdrawalRepository>().fetchBanks(_country);
      if (mounted) setState(() => _banks = b);
    } catch (_) {
      if (mounted) TopSnack.error(context, 'Could not load banks.');
    } finally {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  double get _usd => (int.tryParse(_coins.text) ?? 0) * widget.usdPerCoin;

  Future<void> _submit() async {
    final coins = int.tryParse(_coins.text.trim()) ?? 0;
    if (coins < widget.minCoins || coins > widget.balanceCoins) {
      TopSnack.error(
        context,
        'Enter between ${widget.minCoins} and ${widget.balanceCoins} coins.',
      );
      return;
    }
    if (_method == 'flutterwave' &&
        (_bank == null ||
            _accNo.text.trim().isEmpty ||
            _accName.text.trim().isEmpty)) {
      TopSnack.error(context, 'Fill in your bank details.');
      return;
    }
    if (_method == 'paypal' && !_paypal.text.contains('@')) {
      TopSnack.error(context, 'Enter a valid PayPal email.');
      return;
    }

    setState(() => _busy = true);
    try {
      final msg = await sl<AgentRemoteDataSource>().withdraw({
        'coins': coins,
        'payment_method': _method,
        'idempotency_key': _idem,
        'bank_country': _country,
        if (_method == 'flutterwave') ...{
          'bank_account_name': _accName.text.trim(),
          'bank_account_number': _accNo.text.trim(),
          'bank_name': _bank?['name']?.toString() ?? '',
          'bank_code': _bank?['code']?.toString() ?? '',
        } else
          'paypal_email': _paypal.text.trim(),
      });
      if (!mounted) return;
      TopSnack.success(context, msg);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) TopSnack.error(context, agentErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AgentScaffold(
      title: 'Withdraw commission',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Balance: ${widget.balanceCoins} coins  (\$${(widget.balanceCoins * widget.usdPerCoin).toStringAsFixed(2)})',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _coins,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: agentInput(
              'Coins to withdraw',
              hint: 'Min ${widget.minCoins}',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: Text(
              '≈ \$${_usd.toStringAsFixed(2)} at \$${widget.usdPerCoin} per coin',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _method,
            dropdownColor: const Color(0xFF1C1533),
            style: const TextStyle(color: Colors.white),
            decoration: agentInput('Payment method'),
            items: const [
              DropdownMenuItem(
                value: 'flutterwave',
                child: Text('Bank transfer'),
              ),
              DropdownMenuItem(value: 'paypal', child: Text('PayPal')),
            ],
            onChanged: (v) => setState(() => _method = v ?? 'flutterwave'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _country,
            isExpanded: true,
            dropdownColor: const Color(0xFF1C1533),
            style: const TextStyle(color: Colors.white),
            decoration: agentInput('Country'),
            items: kFlutterwaveCountries
                .map(
                  (c) => DropdownMenuItem(
                    value: c.name,
                    child: Text('${c.name} (${c.currency})'),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null || v == _country) return;
              setState(() => _country = v);
              if (_method == 'flutterwave') _loadBanks();
            },
          ),
          const SizedBox(height: 12),
          if (_method == 'flutterwave') ...[
            _loadingBanks
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _bank,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1C1533),
                    style: const TextStyle(color: Colors.white),
                    decoration: agentInput('Bank'),
                    items: _banks
                        .map(
                          (b) => DropdownMenuItem(
                            value: b,
                            child: Text(
                              (b['name'] ?? '').toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _bank = v),
                  ),
            const SizedBox(height: 12),
            TextField(
              controller: _accNo,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: agentInput('Account number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accName,
              style: const TextStyle(color: Colors.white),
              decoration: agentInput('Account name'),
            ),
          ] else
            TextField(
              controller: _paypal,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: agentInput('PayPal email'),
            ),
          const SizedBox(height: 22),
          AgentPrimaryButton(
            label: 'Request withdrawal',
            busy: _busy,
            onTap: _submit,
          ),
          const SizedBox(height: 8),
          const Text(
            'Requests are reviewed by Moonlight and paid within 3 working days.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
