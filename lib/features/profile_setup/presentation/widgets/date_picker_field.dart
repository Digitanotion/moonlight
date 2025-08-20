import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const DatePickerField({
    super.key,
    required this.label,
    this.selectedDate,
    required this.onDateSelected,
  });

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.dark.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              selectedDate != null
                  ? '${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}'
                  : 'mm/dd/yyyy',
              style: TextStyle(
                color: selectedDate != null
                    ? AppColors.textWhite
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
