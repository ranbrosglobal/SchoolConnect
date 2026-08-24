import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import '../utils/responsive.dart';

/// Shared responsive shell for the multi-step signup flow.
///
/// Renders a soft gradient page, a centered (max 480px) card, an animated
/// step indicator and a consistent header — on any screen size.
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Soft gradient wash
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE8EBFF), AppColors.background],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: context.isMobile ? 20 : 28,
                vertical: 24,
              ),
              child: ResponsiveCenter(
                maxWidth: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (showBack)
                          IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Back',
                          ),
                        const Spacer(),
                        if (currentStep != null)
                          _StepIndicator(
                            currentStep: currentStep!,
                            totalSteps: totalSteps,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildHeader(theme),
                    const SizedBox(height: 24),
                    Container(
                      padding: EdgeInsets.all(context.isMobile ? 20 : 26),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.hairlineBorder),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          child,
                          if (footer != null) ...[
                            const SizedBox(height: 24),
                            footer!,
                          ],
                        ],
                      ).animate().fade(duration: 400.ms).slideY(
                            begin: 0.06,
                            end: 0,
                            duration: 400.ms,
                            curve: Curves.easeOutCubic,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final accent = iconColor ?? AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.68)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ).animate()
              .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 14),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.outline),
        ),
      ],
    );
  }
}

/// Animated 4-dot progress indicator with connecting lines.
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (index) {
        final step = index + 1;
        final isDone = step < currentStep;
        final isCurrent = step == currentStep;
        final color = isDone || isCurrent ? AppColors.primary : AppColors.hairlineBorder;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? AppColors.primary : Colors.white,
                border: Border.all(color: color, width: isCurrent ? 2.5 : 1.5),
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? AppColors.primary : AppColors.outline,
                      ),
                    ),
            ),
            if (index < totalSteps - 1)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 22,
                height: 2.5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isDone ? AppColors.primary : AppColors.hairlineBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        );
      }),
    );
  }
}
