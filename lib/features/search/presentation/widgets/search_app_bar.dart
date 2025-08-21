import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const SearchAppBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.dark.withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: AppColors.textWhite),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                ),
                hintText: 'Search creators, clubs or tags',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                border: InputBorder.none,
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: onClear,
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
