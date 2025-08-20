import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String hintText;

  const DropdownField({
    super.key,
    required this.label,
    this.value,
    required this.items,
    required this.onChanged,
    required this.hintText,
  });

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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.dark.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            onChanged: onChanged,
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  hintText,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ...items.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: const TextStyle(color: AppColors.textWhite),
                  ),
                );
              }).toList(),
            ],
            decoration: const InputDecoration(border: InputBorder.none),
            style: const TextStyle(color: AppColors.textWhite),
            dropdownColor: AppColors.dark,
            icon: const Icon(Icons.arrow_drop_down, color: AppColors.textWhite),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
