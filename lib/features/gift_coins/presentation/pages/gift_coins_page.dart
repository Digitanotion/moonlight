// lib/features/gift_coins/presentation/pages/gift_coins_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/features/gift_coins/presentation/pages/pin_entry_page.dart';
import '../../domain/entities/gift_user.dart';
import '../cubit/transfer_cubit.dart';
import '../widgets/confirm_gift_dialog.dart';
import '../widgets/failed_gift_dialog.dart';
import '../widgets/shimmer_gift.dart';
import '../widgets/success_gift_dialog.dart';
import '../widgets/user_tile.dart';

const int maxPerGift = 1000; // matches your screenshots

class GiftCoinsPage extends StatefulWidget {
  const GiftCoinsPage({Key? key}) : super(key: key);

  @override
  State<GiftCoinsPage> createState() => _GiftCoinsPageState();
}

class _GiftCoinsPageState extends State<GiftCoinsPage> {
  final _usernameController = TextEditingController();
  final _amountController = TextEditingController(text: '');
  final _messageController = TextEditingController();
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    context.read<TransferCubit>().loadBalance();
    _usernameController.addListener(_onUsernameChanged);
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onUsernameChanged);
    _amount_controller_removeListener_safe();
    _usernameController.dispose();
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _amount_controller_removeListener_safe() {
    try {
      _amountController.removeListener(_onAmountChanged);
    } catch (_) {}
  }

  void _onUsernameChanged() {
    final q = _usernameController.text.trim();
    if (q.isEmpty) {
      setState(() => _showResults = false);
      return;
    }

    final selectedUser = context.read<TransferCubit>().state.selectedUser;
    if (selectedUser == null || selectedUser.username != q) {
      setState(() {
        _showResults = true;
      });
      context.read<TransferCubit>().searchUsers(q);
    }
  }

  void _onAmountChanged() => setState(() {}); // refresh button visibility

  Future<void> _refresh() async {
    await context.read<TransferCubit>().loadBalance();
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _onSendPressed() async {
    final cubit = context.read<TransferCubit>();
    final selectedUser = cubit.state.selectedUser;
    final amount = int.tryParse(_amountController.text) ?? 0;

    if (selectedUser == null) {
      _showSnack('Please select a recipient.', error: true);
      return;
    }
    if (amount <= 0) {
      _showSnack('Enter a valid amount.', error: true);
      return;
    }
    if (amount > maxPerGift) {
      _showSnack('Max $maxPerGift coins per gift.', error: true);
      return;
    }

    // Navigate to PIN entry page
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<TransferCubit>(), // pass the existing cubit
          child: PinEntryPage(
            recipientUsername: selectedUser.username,
            amount: amount,
          ),
        ),
        fullscreenDialog: true,
      ),
    );

    if (verified == true) {
      // Proceed to send coins after PIN verification
      // await _sendAndShowResult(
      //   user: selectedUser,
      //   amount: amount,
      //   message: _messageController.text.trim(),
      //   pin: 'dummy-pin', // <- PinEntryPage should pass real PIN here if needed
      // );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => SuccessGiftDialog(
          message:
              'You have transferred $amount coins to ${selectedUser.username}.',
          onDone: () {
            Navigator.of(c).pop();
            setState(() {
              // _selectedUser = null;
              _usernameController.clear();
              _amountController.text = '0';
              _messageController.clear();
            });
            cubit.clearSendSuccess();
          },
        ),
      );
    } else {
      _showSnack('PIN verification failed or cancelled.', error: true);
    }
  }

  Future<void> _sendAndShowResult({
    required GiftUser user,
    required int amount,
    required String message,
    required String pin,
  }) async {
    final cubit = context.read<TransferCubit>();

    await cubit.sendTransfer(pin: pin);

    final state = cubit.state;
    if (state.sendSuccess) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => SuccessGiftDialog(
          message: 'You have transferred $amount coins to ${user.username}.',
          onDone: () {
            Navigator.of(c).pop();
            setState(() {
              // _selectedUser = null;
              _usernameController.clear();
              _amountController.text = '0';
              _messageController.clear();
            });
            cubit.clearSendSuccess();
          },
        ),
      );
    } else if (state.sendError != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => FailedGiftDialog(
          message: state.sendError!,
          onRetry: () async {
            Navigator.of(c).pop();
            await cubit.retrySend();
          },
          onClose: () => Navigator.of(c).pop(),
        ),
      );
    }
  }

  Widget _balancePill(int balance) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1533),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber),
          const SizedBox(width: 10),
          const Text('You have ', style: TextStyle(color: Colors.white70)),
          Text(
            '${formatCoin(balance)} Coins',
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _sendButton(bool enabled, bool loading) {
    return Tooltip(
      message: enabled ? 'Send your gift' : 'Select recipient and amount first',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: ElevatedButton.icon(
          key: ValueKey(enabled),
          onPressed: enabled && !loading ? _onSendPressed : null,
          icon: const Icon(Icons.card_giftcard),
          label: loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Gift'),
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled
                ? Colors.deepOrangeAccent
                : Colors.deepOrangeAccent.withOpacity(0.4),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white70,
            disabledBackgroundColor: Colors.deepOrangeAccent.withOpacity(0.3),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferCubit, TransferState>(
      builder: (context, state) {
        final balance = state.balance;
        final searching = state.searchLoading;
        final results = state.searchResults;
        final canSend = state.canSend;

        return Scaffold(
          backgroundColor: const Color(0xFF060522),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Transfer Coins'),
            centerTitle: true,
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            color: Colors.deepOrangeAccent,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 140),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                state.loading ? const ShimmerGift() : _balancePill(balance),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send to',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141433),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.alternate_email,
                              color: Colors.white38,
                            ),
                            suffixIcon: state.selectedUser != null
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : null,
                            hintText: '@ Enter username',
                            hintStyle: const TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      if (_showResults)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0E2B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: searching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : results.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'No users found',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                )
                              : Column(
                                  children: results.map((u) {
                                    return InkWell(
                                      onTap: () {
                                        context
                                            .read<TransferCubit>()
                                            .selectUser(u);
                                        FocusScope.of(context).unfocus();
                                        _usernameController.text = u.username;
                                        setState(() => _showResults = false);
                                      },
                                      child: UserTile(user: u),
                                    );
                                  }).toList(),
                                ),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Amount',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141433),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (v) => context
                              .read<TransferCubit>()
                              .updateAmount(int.tryParse(v)),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.monetization_on,
                              color: Colors.amber,
                            ),
                            hintText: '0',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Add a message (optional)',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141433),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _messageController,
                          maxLines: null,
                          onChanged: (v) =>
                              context.read<TransferCubit>().updateMessage(v),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Add a message',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Max $maxPerGift coins per gifting',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                top: 8,
              ),
              child: SizedBox(
                width: double.infinity,
                child: _sendButton(canSend, state.sending),
              ),
            ),
          ),
        );
      },
    );
  }
}
