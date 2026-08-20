// lib/features/video_call/presentation/widgets/duration_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';

/// Shown before initiating a call — lets the caller pick how many minutes
/// (and see the coin cost) before any coins are actually spent (doc 1C/1D:
/// "They can choose how many minutes they want the video to last before it
/// starts").
class DurationPickerSheet extends StatefulWidget {
  final String calleeDisplayName;
  final int ratePerMinute;
  final int callerCoinBalance;

  const DurationPickerSheet({
    super.key,
    required this.calleeDisplayName,
    required this.ratePerMinute,
    required this.callerCoinBalance,
  });

  /// Returns the chosen minute count, or null if the user cancelled.
  static Future<int?> show(
    BuildContext context, {
    required String calleeDisplayName,
    required int ratePerMinute,
    required int callerCoinBalance,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DurationPickerSheet(
        calleeDisplayName: calleeDisplayName,
        ratePerMinute: ratePerMinute,
        callerCoinBalance: callerCoinBalance,
      ),
    );
  }

  @override
  State<DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<DurationPickerSheet> {
  int _minutes = 1;

  static const List<int> _presets = [1, 2, 3, 5, 10];

  int get _cost => _minutes * widget.ratePerMinute;
  bool get _canAfford => widget.callerCoinBalance >= _cost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Call ${widget.calleeDisplayName}',
            style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.ratePerMinute} coins per minute',
            style: AppTextStyles.caption.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 20),

          // Preset minute chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presets.map((m) {
              final selected = m == _minutes;
              return GestureDetector(
                onTap: () => setState(() => _minutes = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [
                              AppColors.primary_,
                              AppColors.primary2,
                            ],
                          )
                        : null,
                    color: selected ? null : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Text(
                    '$m min',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Fine-grained +/- stepper for custom durations
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepperButton(
                icon: Icons.remove_rounded,
                onTap: _minutes > 1
                    ? () => setState(() => _minutes--)
                    : null,
              ),
              SizedBox(
                width: 70,
                child: Text(
                  '$_minutes min',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              _StepperButton(
                icon: Icons.add_rounded,
                onTap: _minutes < 120
                    ? () => setState(() => _minutes++)
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Cost summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total cost',
                  style: AppTextStyles.body.copyWith(color: Colors.white70),
                ),
                Text(
                  '$_cost coins',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: _canAfford
                        ? AppColors.accentGreen
                        : AppColors.textRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          if (!_canAfford) ...[
            const SizedBox(height: 8),
            Text(
              'You have ${widget.callerCoinBalance} coins — not enough for this duration.',
              style: AppTextStyles.small.copyWith(color: AppColors.textRed),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _canAfford
                    ? AppColors.accentGreen
                    : Colors.white.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _canAfford
                  ? () => Navigator.of(context).pop(_minutes)
                  : null,
              child: Text(
                _canAfford ? 'Start Call' : 'Not enough coins',
                style: AppTextStyles.labelLarge.copyWith(
                  color: _canAfford ? Colors.white : Colors.white38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(enabled ? 0.1 : 0.04),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white24,
          size: 20,
        ),
      ),
    );
  }
}