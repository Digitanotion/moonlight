import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = true;
  bool _hasFocus = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        setState(() => _hasFocus = _focusNode.hasFocus);
      });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showToggle = widget.isPassword;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ────────────────────────────────────────────────────────────
        Text(
          widget.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: _hasFocus ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        // ── Field ────────────────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: showToggle ? _obscure : false,
            keyboardType: widget.isPassword
                ? TextInputType.visiblePassword
                : TextInputType.emailAddress,
            textInputAction: widget.isPassword
                ? TextInputAction.done
                : TextInputAction.next,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.6),
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: _hasFocus
                  ? AppColors.primary.withOpacity(0.04)
                  : Colors.transparent,

              // ── Prefix icon ─────────────────────────────────────────────
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: _hasFocus
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),

              // ── Suffix: show/hide toggle ─────────────────────────────────
              suffixIcon: showToggle
                  ? GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            key: ValueKey(_obscure),
                            size: 20,
                            color: _hasFocus
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),

              // ── Borders ──────────────────────────────────────────────────
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.8,
                ),
              ),

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
