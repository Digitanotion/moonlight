import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
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
  final _amountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _swiftCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  String _selectedCountry = 'Nigeria';
  final List<String> _countries = ['Nigeria', 'Ghana', 'Kenya', 'South Africa'];

  @override
  void initState() {
    super.initState();
    context.read<WithdrawalCubit>().loadBalance();
  }

  void _showSuccessDialog(Map<String, dynamic> transactionData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1533),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Withdrawal Request Submitted!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your withdrawal request for \$${(int.tryParse(_amountController.text) ?? 0) / 100} has been submitted successfully.',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Funds will be processed within 3-5 business days.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

  Future<void> _submitWithdrawal(String pin) async {
    final cubit = context.read<WithdrawalCubit>();
    await cubit.submitWithdrawal(
      amountUsdCents: (double.tryParse(_amountController.text) ?? 0 * 100)
          .toInt(),
      bankAccountName: _accountNameController.text,
      bankAccountNumber: _accountNumberController.text,
      bankName: _bankNameController.text,
      country: _selectedCountry,
      swift: _swiftCodeController.text.isNotEmpty
          ? _swiftCodeController.text
          : null,
      email: _emailController.text.isNotEmpty ? _emailController.text : null,
      phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
      reason: _reasonController.text.isNotEmpty ? _reasonController.text : null,
      pin: pin,
    );
  }

  void _onProceedToPin() {
    if (_formKey.currentState!.validate()) {
      final amountText = _amountController.text.trim();
      final amount = double.tryParse(amountText) ?? 0;
      final amountCents = (amount).toInt();

      // Debug: Uncomment to see what's happening
      // print('Amount text: "$amountText"');
      // print('Amount: $amount');
      // print('Amount cents: $amountCents');

      if (amountCents < 10000) {
        _showErrorDialog('Minimum withdrawal amount is \$100.00');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WithdrawalPinPage(
            amountUsdCents: amountCents,
            bankAccountName: _accountNameController.text,
            onPinVerified: (pin) {
              Navigator.pop(context);
              _submitWithdrawal(pin);
            },
          ),
        ),
      );
    }
  }

  Widget _buildBalanceCard(int balance) {
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
            '${formatCoin(balance)} coins',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            '~ \$${(balance / 100).toStringAsFixed(1)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines = 1,
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
        listener: (context, state) {
          if (state is WithdrawalSuccess) {
            _showSuccessDialog(state.transactionData);
          } else if (state is WithdrawalError) {
            _showErrorDialog(state.message, retryable: true);
          }
        },
        builder: (context, state) {
          // Update _isSubmitting here
          _isSubmitting = state is WithdrawalSubmitting;
          if (state is WithdrawalLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.deepOrangeAccent,
                ),
              ),
            );
          }

          final balance = state is WithdrawalBalanceLoaded ? state.balance : 0;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _buildBalanceCard(balance),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildInputField(
                        label: 'Amount (\coins)',
                        controller: _amountController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter valid amount';
                          }
                          if (amount * 100 < 10000) {
                            return 'Minimum amount is \$100.00';
                          }
                          if (amount > balance) {
                            return 'Insufficient balance';
                          }
                          return null;
                        },
                      ),
                      _buildInputField(
                        label: 'Bank Name',
                        controller: _bankNameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter bank name';
                          }
                          return null;
                        },
                      ),
                      _buildInputField(
                        label: 'Account Name',
                        controller: _accountNameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter account name';
                          }
                          return null;
                        },
                      ),
                      _buildInputField(
                        label: 'Account Number',
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter account number';
                          }
                          if (value.length < 8) {
                            return 'Please enter valid account number';
                          }
                          return null;
                        },
                      ),
                      Column(
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
                              items: _countries.map((String country) {
                                return DropdownMenuItem(
                                  value: country,
                                  child: Text(
                                    country,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedCountry = newValue!;
                                });
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
                      ),
                      _buildInputField(
                        label: 'SWIFT Code (Optional)',
                        controller: _swiftCodeController,
                        validator: (value) => null,
                      ),
                      _buildInputField(
                        label: 'Email (Optional)',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => null,
                      ),
                      _buildInputField(
                        label: 'Phone (Optional)',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (value) => null,
                      ),
                      _buildInputField(
                        label: 'Reason (Optional)',
                        controller: _reasonController,
                        maxLines: 3,
                        validator: (value) => null,
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
          padding: const EdgeInsets.all(16.0),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
