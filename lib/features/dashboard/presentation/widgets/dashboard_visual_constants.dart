import 'package:flutter/material.dart';

// Define luxurious and magical colors for the dashboard, supporting dark and light modes.

class DashboardVisualConstants {
  // Primary color palette for a luxurious feel
  static const Color luxuriousPurpleStart = Color(0xFF6A0DAD); // Royal Purple
  static const Color luxuriousPurpleEnd = Color(0xFF9370DB); // Medium Purple

  // Accent colors for highlights and accents
  static const Color goldenAccent = Color(0xFFFFD700); // Bright Gold
  static const Color etherealWhite = Color(
    0xFFF0F8FF,
  ); // Alice Blue for ethereal highlights
  static const Color deepCosmicBlue = Color(
    0xFF0B1220,
  ); // Very dark blue for backgrounds

  // Define colors for specific dashboard elements
  static const Color salesColor = Color(0xFF2ECC71); // Emerald Green (vibrant)
  static const Color purchasesColor = Color(
    0xFFE74C3C,
  ); // Alizarin Crimson (vibrant)
  static const Color grossColor = Color(0xFFF39C12); // Orange (vibrant)
  static const Color netColor = Color(0xFF9B59B6); // Amethyst Purple (vibrant)
  static const Color customerDebtColor = Color(
    0xFF3498DB,
  ); // Peter River Blue (vibrant)
  static const Color supplierDebtColor = Color(
    0xFF1ABC9C,
  ); // Turquoise (vibrant)

  // Spotlight colors
  static Color getSpotlightStart(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? deepCosmicBlue
      : luxuriousPurpleStart;
  static Color getSpotlightMid(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF11213A)
      : const Color(0xFF2C1E4A);
  static Color getSpotlightEnd(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1F3B67)
      : luxuriousPurpleEnd;

  // General constants for luxurious designs
  static Color getLuxuriousCardBgStart(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? deepCosmicBlue
      : luxuriousPurpleStart;
  static Color getLuxuriousCardBgEnd(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0D1B2A)
      : luxuriousPurpleEnd;
  static Color getLuxuriousCardBorder(BuildContext context) => goldenAccent;
  static Color getLuxuriousCardShadow(BuildContext context) =>
      const Color(0x80FFD700); // Intense gold shadow
  static Color getLuxuriousTitleColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? etherealWhite
      : Colors.grey.shade800;
  static Color getLuxuriousSubtitleColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFFA0A0C0);
  static Color getLuxuriousValueColor(BuildContext context) => goldenAccent;
  static Color getLuxuriousCardIconColor(BuildContext context) => goldenAccent;
}
