import 'package:flutter/material.dart';
import 'colors.dart';

/// Spacing scale. Everything should snap to these steps so the vertical
/// rhythm stays consistent across every screen.
class AppSpace {
  const AppSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 56;

  /// Standard horizontal page gutter on phones.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: 20);

  /// Standard scroll padding: gutter + breathing room top/bottom.
  static const EdgeInsets pageScroll = EdgeInsets.fromLTRB(20, 16, 20, 32);
}

/// Corner radii. Mostly generous — soft shapes read as "modern" and make the
/// dense data screens feel calmer.
class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 26;
  static const double xxl = 34;
  static const double pill = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// Layered elevation. Shadows are tinted with the surface's own hue rather
/// than pure black — that is what separates a polished app from a default one.
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> soft([Color tint = AppColors.ink]) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> card([Color tint = AppColors.ink]) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.05),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.03),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> lifted([Color tint = AppColors.ink]) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.10),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: tint.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// Colored glow used under gradient buttons and accented avatars.
  static List<BoxShadow> glow(Color color, {double strength = 0.32}) => [
        BoxShadow(
          color: color.withValues(alpha: strength),
          blurRadius: 22,
          spreadRadius: -2,
          offset: const Offset(0, 10),
        ),
      ];
}

/// Motion tokens — one place to keep animation timing coherent.
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration page = Duration(milliseconds: 380);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
  static const Curve springy = Curves.easeOutBack;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// Delay used for staggered list/grid entrances.
  static Duration stagger(int index, {Duration step = const Duration(milliseconds: 45)}) =>
      Duration(milliseconds: step.inMilliseconds * index);
}

/// Which "skin" a screen wears. Resolved from the signed-in user's role so
/// every role gets its own accent without duplicating screen code.
enum AppRoleSkin { student, teacher, admin, superAdmin }

class AppRoleStyle {
  final AppRoleSkin skin;
  final String label;
  final Color accent;
  final Color accentDark;
  final Color accentSoft;
  final Color accentFaint;
  final LinearGradient gradient;
  final IconData icon;

  const AppRoleStyle({
    required this.skin,
    required this.label,
    required this.accent,
    required this.accentDark,
    required this.accentSoft,
    required this.accentFaint,
    required this.gradient,
    required this.icon,
  });

  static const AppRoleStyle student = AppRoleStyle(
    skin: AppRoleSkin.student,
    label: 'Student',
    accent: AppColors.studentAccent,
    accentDark: AppColors.studentAccentDark,
    accentSoft: AppColors.studentAccentSoft,
    accentFaint: Color(0xFFF7F5FF),
    gradient: AppGradients.student,
    icon: Icons.school_rounded,
  );

  static const AppRoleStyle teacher = AppRoleStyle(
    skin: AppRoleSkin.teacher,
    label: 'Teacher',
    accent: AppColors.teacherAccent,
    accentDark: AppColors.teacherAccentDark,
    accentSoft: AppColors.teacherAccentSoft,
    accentFaint: Color(0xFFF3F7FF),
    gradient: AppGradients.teacher,
    icon: Icons.cast_for_education_rounded,
  );

  static const AppRoleStyle admin = AppRoleStyle(
    skin: AppRoleSkin.admin,
    label: 'School Admin',
    accent: AppColors.adminAccent,
    accentDark: AppColors.adminAccentDark,
    accentSoft: AppColors.adminAccentSoft,
    accentFaint: Color(0xFFF0FBF7),
    gradient: AppGradients.admin,
    icon: Icons.apartment_rounded,
  );

  static const AppRoleStyle superAdmin = AppRoleStyle(
    skin: AppRoleSkin.superAdmin,
    label: 'Super Admin',
    accent: AppColors.superAccent,
    accentDark: AppColors.superAccentDark,
    accentSoft: AppColors.superAccentSoft,
    accentFaint: Color(0xFFF4F5FB),
    gradient: AppGradients.superAdmin,
    icon: Icons.hub_rounded,
  );

  static const List<AppRoleStyle> all = [student, teacher, admin, superAdmin];
}

/// Typography helpers on top of the Material text theme.
///
/// The app relies on the platform font (no bundled binaries) so the character
/// comes from tight tracking, confident weights and generous line height.
class AppText {
  const AppText._();

  static const TextStyle display = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.12,
    color: AppColors.ink,
  );

  static const TextStyle title = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
    color: AppColors.ink,
  );

  static const TextStyle section = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.25,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.45,
    color: AppColors.inkSoft,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.inkFaint,
  );

  /// Small uppercase label used above metrics and in section eyebrows.
  static const TextStyle eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.9,
    color: AppColors.inkFaint,
  );

  static const TextStyle metric = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.05,
    color: AppColors.ink,
  );
}
