import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/features/clubs/presentation/cubit/donate_club_cubit.dart';
import 'package:moonlight/widgets/top_snack.dart';

class SupportClubPage extends StatefulWidget {
  final String clubName;
  final String clubDescription;
  final String clubAvatar;

  const SupportClubPage({
    super.key,
    required this.clubName,
    required this.clubDescription,
    required this.clubAvatar,
  });

  @override
  State<SupportClubPage> createState() => _SupportClubPageState();
}

class _SupportClubPageState extends State<SupportClubPage> {
  int? selectedAmount;
  bool isCustom = false;

  final TextEditingController customCtrl = TextEditingController();
  final TextEditingController messageCtrl = TextEditingController();

  final List<int> presetAmounts = [100, 500, 1000];

  @override
  Widget build(BuildContext context) {
    final canConfirm = selectedAmount != null && selectedAmount! > 0;

    return BlocListener<DonateClubCubit, DonateClubState>(
      listener: (context, state) {
        if (state.loading) {
          _showProcessing();
        }

        if (state.success) {
          Navigator.pop(context); // close processing
          _showSuccess();
          context.read<DonateClubCubit>().reset();
        }

        if (state.error != null) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF060B2E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: const Text('Support Club'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _clubHeader(),
              const SizedBox(height: 20),
              _amountSelector(),
              const SizedBox(height: 20),
              BlocBuilder<DonateClubCubit, DonateClubState>(
                builder: (context, state) {
                  if (state.balance == null) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    );
                  }

                  return _paymentSource(state.balance!);
                },
              ),
              const SizedBox(height: 20),
              _messageBox(),
            ],
          ),
        ),
        bottomSheet: _confirmButton(canConfirm),
      ),
    );
  }

  // ───────────────── HEADER ─────────────────

  Widget _clubHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(widget.clubAvatar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.clubName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.clubDescription,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── AMOUNT ─────────────────

  Widget _amountSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Donation Amount',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [...presetAmounts.map(_presetTile), _customTile()],
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isCustom
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextField(
                      controller: customCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        setState(() {
                          selectedAmount = parsed != null && parsed > 0
                              ? parsed
                              : null;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter custom amount',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(
                          Icons.monetization_on,
                          color: Colors.orange,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0E1440),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _presetTile(int amount) {
    final active = selectedAmount == amount && !isCustom;

    return GestureDetector(
      onTap: () {
        setState(() {
          isCustom = false;
          customCtrl.clear();
          selectedAmount = amount;
        });
      },
      child: _amountBox(active, '${formatCoin(amount)}', 'Coins'),
    );
  }

  Widget _customTile() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isCustom = true;
          selectedAmount = null;
        });
      },
      child: _amountBox(isCustom, 'Custom', 'Amount'),
    );
  }

  Widget _amountBox(bool active, String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? const Color(0xFFFF7A00) : Colors.white24,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────── PAYMENT ─────────────────

  Widget _paymentSource(int myBalance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Payment Source',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          _PaymentTile(
            icon: Icons.account_balance_wallet,
            title: 'Wallet Balance',
            subtitle: '${formatCoin(myBalance)} Coins',
            selected: true,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, RouteNames.buyCoins),
            child: _PaymentTile(
              icon: Icons.add_circle_outline,
              title: 'Buy More Coins',
              subtitle: 'Top up your wallet',
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── MESSAGE ─────────────────

  Widget _messageBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Describe Donation',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: messageCtrl,
            maxLength: 200,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Say something nice to the club...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0E1440),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── CONFIRM ─────────────────

  Widget _confirmButton(bool enabled) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled
                ? const Color(0xFFFF7A00)
                : Colors.orange.withOpacity(.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: enabled ? _showConfirmSheet : null,
          child: const Text('Confirm Donation'),
        ),
      ),
    );
  }

  void _showConfirmSheet() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF0E1440),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ConfirmSheet(
        amount: selectedAmount!,
        message: messageCtrl.text,
        club: widget.clubName,
      ),
    );

    if (confirmed == true && mounted) {
      if (context.read<DonateClubCubit>().state.balance as int <
          selectedAmount!) {
        TopSnack.error(context, 'Insufficient balance.');
        return;
      }

      context.read<DonateClubCubit>().donate(
        coins: selectedAmount!,
        message: messageCtrl.text,
      );
    }
  }

  void _showProcessing() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProcessingDialog(),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _SuccessDialog(club: widget.clubName, amount: selectedAmount!),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [Color(0xFF1A1F5C), Color(0xFF10154A)],
      ),
    );
  }
}

// ───────────────── SUPPORT WIDGETS ─────────────────

class _PaymentTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;

  const _PaymentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? const Color(0xFFFF7A00) : Colors.white24,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  final int amount;
  final String message;
  final String club;

  const _ConfirmSheet({
    required this.amount,
    required this.message,
    required this.club,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Confirm Donation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          _row('Amount', '${formatCoin(amount)}'),
          _row('Payment method', 'Wallet Balance'),
          if (message.isNotEmpty) _row('Message', message),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingDialog extends StatelessWidget {
  const _ProcessingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1440),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF7A00)),
            const SizedBox(height: 16),
            const Text(
              'Processing Your Payment...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please wait while we process your transaction.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final String club;
  final int amount;

  const _SuccessDialog({required this.club, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1A7A),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank you',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your donation has been sent successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1440),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'You supported $club with ${formatCoin(amount)} coins',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFF7A00),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // leave support page
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
