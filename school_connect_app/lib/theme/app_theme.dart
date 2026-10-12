import 'package:flutter/material.dart';
import 'colors.dart';
import 'tokens.dart';

/// The single source of truth for the app's Material theme.
///
/// Component themes are configured centrally so individual screens only worry
/// about layout — buttons, inputs, sheets, snackbars and nav bars all inherit
/// the same shape language from here.
class AppTheme {
  static ThemeData get lightTheme => _build(_lightScheme(AppColors.primary));

  /// Accent-aware theme. Wrap a subtree in `Theme(data: AppTheme.withAccent(c))`
  /// to tint all Material widgets to a role's accent without extra plumbing.
  static ThemeData withAccent(Color accent) => _build(_lightScheme(accent));

  static ColorScheme _lightScheme(Color primary) => ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        surfaceContainerLowest: AppColors.surfaceContainerLowest,
        surfaceContainerLow: AppColors.surfaceContainerLow,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        surfaceContainerHighest: AppColors.surfaceContainerHighest,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      );

  static ThemeData _build(ColorScheme scheme) {
    final accent = scheme.primary;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SoftPageTransitionsBuilder(),
          TargetPlatform.iOS: SoftPageTransitionsBuilder(),
          TargetPlatform.macOS: SoftPageTransitionsBuilder(),
          TargetPlatform.windows: SoftPageTransitionsBuilder(),
          TargetPlatform.linux: SoftPageTransitionsBuilder(),
        },
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: AppText.display.copyWith(fontSize: 34),
        displayMedium: AppText.display.copyWith(fontSize: 28),
        displaySmall: AppText.title,
        headlineMedium: AppText.title,
        headlineSmall: AppText.title.copyWith(fontSize: 19),
        titleLarge: AppText.section,
        titleMedium: AppText.cardTitle,
        titleSmall: AppText.cardTitle.copyWith(fontSize: 14),
        bodyLarge: AppText.body.copyWith(fontSize: 15),
        bodyMedium: AppText.body,
        bodySmall: AppText.caption,
        labelLarge: AppText.cardTitle.copyWith(fontSize: 14),
        labelMedium: AppText.caption,
        labelSmall: AppText.eyebrow,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.section.copyWith(fontSize: 18, color: AppColors.ink),
        iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
        actionsIconTheme: const IconThemeData(color: AppColors.ink, size: 22),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brLg,
          side: const BorderSide(color: AppColors.hairlineBorder),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairlineBorder,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: AppText.cardTitle.copyWith(color: Colors.white, fontSize: 14.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: AppText.cardTitle.copyWith(color: Colors.white, fontSize: 14.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: accent.withValues(alpha: 0.35), width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: AppText.cardTitle.copyWith(fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: AppText.cardTitle.copyWith(fontSize: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          highlightColor: accent.withValues(alpha: 0.08),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.inkSoft, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        hintStyle: AppText.body.copyWith(color: AppColors.inkFaint),
        labelStyle: AppText.caption,
        floatingLabelStyle: AppText.caption.copyWith(color: accent),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        prefixIconColor: AppColors.inkFaint,
        suffixIconColor: AppColors.inkFaint,
        border: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: const BorderSide(color: AppColors.hairlineBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: const BorderSide(color: AppColors.hairlineBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainer,
        selectedColor: accent.withValues(alpha: 0.14),
        side: BorderSide.none,
        labelStyle: AppText.caption.copyWith(color: AppColors.inkSoft),
        secondaryLabelStyle: AppText.caption.copyWith(color: accent),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brPill),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.outlineVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
        titleTextStyle: AppText.title.copyWith(fontSize: 18),
        contentTextStyle: AppText.body,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(16),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.92),
          borderRadius: AppRadius.brXs,
        ),
        textStyle: AppText.caption.copyWith(color: Colors.white),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: accent.withValues(alpha: 0.12),
        circularTrackColor: accent.withValues(alpha: 0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : AppColors.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.outlineVariant, width: 1.6),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXs),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.inkSoft,
        titleTextStyle: AppText.cardTitle,
        subtitleTextStyle: AppText.caption,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: AppColors.inkFaint,
        labelStyle: AppText.cardTitle.copyWith(fontSize: 14),
        unselectedLabelStyle: AppText.cardTitle.copyWith(
          fontSize: 14,
          color: AppColors.inkFaint,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: accent, width: 2.5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),
      dividerColor: AppColors.hairlineBorder,
      splashColor: accent.withValues(alpha: 0.06),
      highlightColor: accent.withValues(alpha: 0.04),
    );
  }
}

/// Soft, buttery page transition used everywhere in the app.
///
/// The incoming page fades in while gliding up a few pixels with a gentle
/// ease-out curve — calmer than the stock zoom/cupertino transitions and
/// cheap to render (no blur or scaling, so text stays crisp mid-motion).
class SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
