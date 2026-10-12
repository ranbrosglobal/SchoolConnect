import 'package:flutter/material.dart';

/// School Connect color system.
///
/// Two layers:
///
///  1. **Brand + neutrals** — the app chrome (login, shell, AI copilot).
///     Indigo-iris primary with a violet companion and a mint accent, on a
///     cool "paper" canvas with deep indigo ink for text. Deliberately not
///     the default Material teal/blue so the product has a signature.
///
///  2. **Role accents** — each role gets its own accent so a student, teacher
///     and admin can tell their app apart at a glance:
///        student  → iris / violet      (playful, warm)
///        teacher  → azure / sky        (calm, productive)
///        admin    → emerald / teal     (administrative)
///        super    → ink / amber        (system-level)
///
/// All legacy constant names are preserved so existing screens keep compiling
/// while they migrate to the tokens in `tokens.dart`.
class AppColors {
  // ─────────────────────────────────────────────────────────────────────────
  // Brand — iris
  // ─────────────────────────────────────────────────────────────────────────

  static const Color primary = Color(0xFF5B4BE0);
  static const Color primaryDark = Color(0xFF3A2DB0);
  static const Color primaryLight = Color(0xFF8B7CF6);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFE6E3FF);
  static const Color onPrimaryContainer = Color(0xFF1B1464);
  static const Color primarySoft = Color(0xFFF1EFFF);

  /// Vivid violet companion used for gradients and highlights.
  static const Color secondary = Color(0xFF9B4DFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFF4E8FF);
  static const Color onSecondaryContainer = Color(0xFF3B1063);

  /// Cyan — the "signal" accent (live badges, AI glow).
  static const Color tertiary = Color(0xFF06B6D4);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFDCF7FB);
  static const Color onTertiaryContainer = Color(0xFF06363F);

  // ─────────────────────────────────────────────────────────────────────────
  // Semantic
  // ─────────────────────────────────────────────────────────────────────────

  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF047857);
  static const Color successSoft = Color(0xFFDFFAF0);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFEF3DE);

  static const Color danger = Color(0xFFF43F5E);
  static const Color dangerDark = Color(0xFFBE123C);
  static const Color dangerSoft = Color(0xFFFFE4EA);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoSoft = Color(0xFFE3EEFF);

  static const Color error = Color(0xFFE11D48);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFE4EA);
  static const Color onErrorContainer = Color(0xFF881337);

  // ─────────────────────────────────────────────────────────────────────────
  // Neutrals — "ink on paper"
  // ─────────────────────────────────────────────────────────────────────────

  static const Color ink = Color(0xFF141633); // deep indigo-black
  static const Color inkSoft = Color(0xFF5C628C);
  static const Color inkFaint = Color(0xFF9298B8);

  static const Color background = Color(0xFFF4F5FB);
  static const Color onBackground = ink;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = ink;

  static const Color surfaceDim = Color(0xFFE3E5F0);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF8F9FD);
  static const Color surfaceContainer = Color(0xFFF1F2F9);
  static const Color surfaceContainerHigh = Color(0xFFE9EBF5);
  static const Color surfaceContainerHighest = Color(0xFFDFE2EF);

  static const Color outline = Color(0xFF6B7194);
  static const Color outlineVariant = Color(0xFFD3D7E8);
  static const Color hairlineBorder = Color(0xFFE6E8F3);

  // Legacy aliases (kept for older screens).
  static const Color lightGreen = Color(0xFFE4FBEF);
  static const Color darkTeal = Color(0xFF2A7F72);

  // ─────────────────────────────────────────────────────────────────────────
  // Role accents
  // ─────────────────────────────────────────────────────────────────────────

  /// Student — iris/violet.
  static const Color studentAccent = Color(0xFF6D5DF6);
  static const Color studentAccentDark = Color(0xFF4C3BD4);
  static const Color studentAccentSoft = Color(0xFFEFECFF);

  /// Teacher — azure/sky.
  static const Color teacherAccent = Color(0xFF2F6BFF);
  static const Color teacherAccentDark = Color(0xFF1746C2);
  static const Color teacherAccentSoft = Color(0xFFE8EFFF);

  /// School admin — emerald/teal.
  static const Color adminAccent = Color(0xFF0E9F7E);
  static const Color adminAccentDark = Color(0xFF076A54);
  static const Color adminAccentSoft = Color(0xFFE1F7F0);

  /// Super admin — ink/amber.
  static const Color superAccent = Color(0xFF1F2545);
  static const Color superAccentDark = Color(0xFF0C0F26);
  static const Color superAccentSoft = Color(0xFFEDEFF9);
  static const Color superHighlight = Color(0xFFF5A524);
}

/// Multi-stop gradients used by headers, buttons and AI surfaces.
class AppGradients {
  const AppGradients._();

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C6BFF), Color(0xFF5B4BE0), Color(0xFF9B4DFF)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient brandDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A2DB0), Color(0xFF6D4BE0), Color(0xFFB54DFF)],
  );

  static const LinearGradient student = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C6BFF), Color(0xFF6D5DF6), Color(0xFF9B4DFF)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient teacher = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4C86FF), Color(0xFF2F6BFF), Color(0xFF1746C2)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient admin = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2BC49B), Color(0xFF0E9F7E), Color(0xFF076A54)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient superAdmin = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A3160), Color(0xFF1F2545), Color(0xFF0C0F26)],
    stops: [0.0, 0.5, 1.0],
  );

  /// AI copilot — iris → cyan, used on the assistant FAB and header.
  static const LinearGradient ai = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6D5DF6), Color(0xFF5B4BE0), Color(0xFF06B6D4)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF10B981)],
  );

  static const LinearGradient amber = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
  );

  static const LinearGradient rose = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFB7185), Color(0xFFF43F5E)],
  );

  /// Cool "paper" wash for flat page backgrounds.
  static const LinearGradient canvas = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEFF1FB), Color(0xFFF4F5FB)],
  );

  /// Glassy overlay for content sitting on a gradient header.
  static LinearGradient glassOverlay({double opacity = 1}) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.22 * opacity),
          Colors.white.withValues(alpha: 0.07 * opacity),
        ],
      );
}
