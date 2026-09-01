import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF000080);
  static const Color primary_2 = Color.fromARGB(255, 17, 17, 165);
  static const Color secondary = Color(0xFFFF6A00);
  static const Color green = Color(0xFF55DCE35);
  static const Color cardDark = Color(0xFF1E1E2E);
  static const Color divider = Color(0xFF2D2D3D);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color background = Color(0xFFFFFFFF);
  static const Color textWhite = Color(0xFFFFFFFF);
  // static const Color textPrimary = Color.fromARGB(255, 214, 214, 214);
  // static const Color textSecondary = Color(0xFF636E72);
  static const Color dotInactive = Color.fromARGB(255, 141, 143, 144);
  static const Color border = Color(0xFFE0E0E0);
  static const Color dark = Color(0xFF0A0C0E);
  static const Color textRed = Color(0xFFEF4444);
  static const bgTop = Color(0xFF0E1A58); // deep blue
  static const bgBottom = Color(0xFF060A1E); // near-black blue

  static const card = Color(0xFF0F1630);

  static const primary_ = Color(0xFFFF5B2E); // orange
  static const primary2 = Color(0xFFFF7A3D); // orange light

  static const accentGreen = Color(0xFF31D377);
  static const textPrimary = Colors.white;
  // static const divider = Color(0xFF1D2646);
  static const Color navy = Color(
    0xFF07133A,
  ); // deep navy used in comments header
  static const Color navyDark = Color(0xFF050D2C);
  static const Color bluePrimary = Color(0xFF0B1E6B); // gradient top
  static const Color bluePrimaryDark = Color(0xFF031049);
  static const Color surface = Color(
    0xFF0F1529,
  ); // dark card surface under photo
  static const Color onSurface = Color(0xFFE8ECF6);
  static const Color secondaryText = Color(0xFF98A2B3);
  static const Color success = Color(0xFF31D873); // green pill (Superstar)
  static const Color warning = Color(0xFFFFC107); // badge dot
  static const Color like = Color(0xFFFF5A5F);
  static const Color hashtag = Color(0xFF39C17F); // tag chip outline/fill
  static const Color info = Color(0xFF4C8DFF); // Nominal member pill
  static const Color vip = Color(0xFF9B5CFF);

  // ── Chat ────────────────────────────────────────────────────────────────
  // Outgoing bubble: a light, warm porcelain surface (WhatsApp model —
  // outgoing is the light bubble). Dark text on it is crisp, and orange
  // accents/icons read clearly against it instead of vanishing into a
  // saturated orange fill.
  static const Color chatOutgoingTop = Color(0xFFFFF3EA);
  static const Color chatOutgoingBottom = Color(0xFFFCE6D4);
  static const Color chatOutgoingText = Color(0xFF201A16);
  static const Color chatOutgoingMeta = Color(0xFF9A6A4E);
  // Incoming bubble: soft slate that reads clearly on the navy chat canvas.
  static const Color chatIncomingTop = Color(0xFF20263F);
  static const Color chatIncomingBottom = Color(0xFF191E33);
  static const Color chatIncomingBorder = Color(0xFF2E3556);
  // Chat canvas (behind the messages) + the faint doodle texture on it.
  static const Color chatCanvasTop = Color(0xFF0C1330);
  static const Color chatCanvasBottom = Color(0xFF070B1E);
  static const Color chatTexture = Color(0x0DFFFFFF);
}
