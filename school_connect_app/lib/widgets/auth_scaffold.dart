import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../utils/responsive.dart';
import 'kit/kit.dart';

/// Shared responsive shell for the multi-step signup flow.
///
/// Renders a soft aurora page, a centered (max 480px) card, an animated step
/// indicator and a consistent header — on any screen size.
class AuthScaffold extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  final int? currentStep;
  final int totalSteps;
  final Widget? footer;
  final bool showBack;

  const AuthScaffold({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    this.currentStep,
    this.totalSteps = 4,
    this.footer,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.primary;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AuroraBackground(
        tint: accent,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: context.isMobile ? 20 : 28,
              vertical: 20,
            ),
            child: ResponsiveCenter(
              maxWidth: 480,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (showBack)
                        Pressable(
                          onTap: () => Navigator.maybePop(context),
                          borderRadius: AppRadius.brMd,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.brMd,
                              border: Border.all(color: AppColors.hairlineBorder),
                              boxShadow: AppShadows.soft(),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                size: 19, color: AppColors.ink),
                          ),
                        ),
                      const Spacer(),
                      if (currentStep != null)
                        _StepIndicator(
                          currentStep: currentStep!,
                          totalSteps: totalSteps,
                          accent: accent,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  _buildHeader(accent),
                  const SizedBox(height: AppSpace.xl),
                  AppCard(
                    padding: EdgeInsets.all(context.isMobile ? 20 : 26),
                    radius: AppRadius.xl,
                    shadow: AppShadows.lifted(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        child,
                        if (footer != null) ...[
                          const SizedBox(height: AppSpace.xl),
                          footer!,
                        ],
                      ],
                    ),
                  )
                      .animate()
                      .fade(duration: 420.ms)
                      .slideY(begin: 0.06, end: 0, duration: 440.ms, curve: Curves.easeOutCubic),
                  const SizedBox(height: AppSpace.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, Color.lerp(accent, Colors.black, 0.24)!],
              ),
              borderRadius: AppRadius.brMd,
              boxShadow: AppShadows.glow(accent, strength: 0.30),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          )
              .animate()
              .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.easeOutBack,
              ),
        const SizedBox(height: AppSpace.md),
        Text(title, style: AppText.display.copyWith(fontSize: 26)),
        const SizedBox(height: 6),
        Text(subtitle, style: AppText.body.copyWith(fontSize: 13.5)),
      ],
    );
  }
}

/// Step indicator with connecting lines and a check on completed steps.
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final Color accent;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (index) {
        final step = index + 1;
        final isDone = step < currentStep;
        final isCurrent = step == currentStep;
        final color = isDone || isCurrent ? accent : AppColors.outlineVariant;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.emphasized,
              width: isCurrent ? 30 : 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDone || isCurrent
                    ? LinearGradient(
                        colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
                      )
                    : null,
                color: isDone || isCurrent ? null : AppColors.surface,
                border: Border.all(color: color, width: isCurrent ? 0 : 1.5),
                boxShadow: isCurrent ? AppShadows.glow(accent, strength: 0.3) : null,
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : Text(
                      '$step',
                      style: AppText.caption.copyWith(
                        fontSize: 12,
                        color: isCurrent ? Colors.white : AppColors.inkFaint,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            if (index < totalSteps - 1)
              AnimatedContainer(
                duration: AppMotion.base,
                width: 20,
                height: 2.5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isDone ? accent : AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        );
      }),
    );
  }
}
