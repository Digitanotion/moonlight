// lib/features/auth/presentation/widgets/auth_ui.dart
//
// Shared look for the Login and Sign-up screens (dark navy gradient, glow
// orbs, frosted-glass card, rounded floating-label fields, gradient CTA).

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/core/widgets/app_logo_loader.dart';

const kAuthBgTop = Color(0xFF0B1240);
const kAuthBgBottom = Color(0xFF05071A);
const kAuthAccent = Color(0xFFFF6A00);
const kAuthAccentSoft = Color(0xFFFF9A4D);

// ── building blocks ────────────────────────────────────────────────────

class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kAuthBgTop, kAuthBgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -90,
          child: AuthOrb(size: 320, color: const Color(0xFF3D4DFF)),
        ),
        Positioned(
          bottom: 120,
          left: -140,
          child: AuthOrb(size: 300, color: kAuthAccent.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

class AuthOrb extends StatelessWidget {
  final double size;
  final Color color;
  const AuthOrb({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.32), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            AssetPaths.logo,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(
              Icons.nights_stay_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Moonlight',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class AuthRoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const AuthRoundIcon({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class AuthInviteBadge extends StatelessWidget {
  const AuthInviteBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: kAuthAccent.withValues(alpha: 0.14),
        border: Border.all(color: kAuthAccent.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_rounded, color: kAuthAccentSoft, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "You've been invited by a Moonlight agent. Your code is applied "
              'automatically once you sign up.',
              style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthGlass extends StatelessWidget {
  final Widget child;
  const AuthGlass({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool password;
  final bool last;
  final TextInputType keyboard;
  final TextCapitalization capitalize;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.password = false,
    this.last = false,
    this.keyboard = TextInputType.text,
    this.capitalize = TextCapitalization.none,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.password && _hide,
      keyboardType: widget.password
          ? TextInputType.visiblePassword
          : widget.keyboard,
      textCapitalization: widget.capitalize,
      textInputAction: widget.last
          ? TextInputAction.done
          : TextInputAction.next,
      autocorrect: false,
      cursorColor: kAuthAccent,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
        floatingLabelStyle: const TextStyle(
          color: kAuthAccentSoft,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          widget.icon,
          size: 20,
          color: Colors.white.withValues(alpha: 0.6),
        ),
        suffixIcon: widget.password
            ? IconButton(
                splashRadius: 18,
                onPressed: () => setState(() => _hide = !_hide),
                icon: Icon(
                  _hide
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kAuthAccent, width: 1.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class AuthStrengthBar extends StatelessWidget {
  final int level; // 0..4
  const AuthStrengthBar({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    if (level == 0) return const SizedBox(height: 0);
    const labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    final color = [
      Colors.transparent,
      const Color(0xFFEF4444),
      const Color(0xFFF5A623),
      const Color(0xFF7ED957),
      const Color(0xFF1FBF75),
    ][level];
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
      child: Row(
        children: [
          for (var i = 1; i <= 4; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                margin: EdgeInsets.only(right: i == 4 ? 0 : 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i <= level
                      ? color
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
          const SizedBox(width: 10),
          Text(
            labels[level],
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null && !loading ? 0.6 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [kAuthAccent, kAuthAccentSoft],
            ),
            boxShadow: [
              BoxShadow(
                color: kAuthAccent.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: loading
              ? const SizedBox(width: 26, height: 26, child: AppLogoLoader())
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

class AuthGoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const AuthGoogleButton({
    super.key,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: loading
            ? const Center(
                child: SizedBox(width: 26, height: 26, child: AppLogoLoader()),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    AssetPaths.googleIcon,
                    width: 22,
                    height: 22,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Color(0xFF111322),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  final String label;
  const AuthOrDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(color: Colors.white.withValues(alpha: 0.16), height: 1),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12.5,
            ),
          ),
        ),
        line,
      ],
    );
  }
}
