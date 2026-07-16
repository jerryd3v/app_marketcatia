import 'package:flutter/material.dart';

/// Tokens de [marketcatia/src/index.css].
class AppColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryEnd = Color(0xFF8B5CF6);
  static const Color secondaryStart = Color(0xFF818CF8);
  static const Color secondaryEnd = Color(0xFFA78BFA);
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF475569);
  static const Color textLight = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color discount = Color(0xFFEF4444);
  static const Color discountBg = Color(0xFFFEF2F2);
  static const Color retail = Color(0xFF10B981);
  static const Color wholesale = Color(0xFF8B5CF6);
  static const Color featured = Color(0xFFF59E0B);
  static const Color featuredBg = Color(0xFFFFFBEB);
  static const Color success = Color(0xFF10B981);
  static const Color campaignStart = Color(0xFFEF4444);
  static const Color campaignEnd = Color(0xFFDC2626);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryEnd],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryStart, secondaryEnd],
  );

  static const LinearGradient navActiveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1A6366F1),
      Color(0x1A8B5CF6),
    ],
  );

  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 6,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: primary.withValues(alpha: 0.1),
          blurRadius: 25,
          offset: const Offset(0, 10),
        ),
      ];

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
}
