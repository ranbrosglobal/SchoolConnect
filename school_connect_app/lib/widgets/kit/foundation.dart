import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Surfaces
// ─────────────────────────────────────────────────────────────────────────────

/// The standard elevated content surface.
///
/// One shared container means every card in the app has the same radius,
/// border and tinted shadow — the fastest way to stop a UI looking assembled
/// from unrelated parts.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool elevated;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.md),
    this.margin,
    this.color,
    this.borderColor,
    this.radius = AppRadius.lg,
    this.elevated = true,
    this.gradient,
    this.onTap,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    Widget surface = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: br,
        border: Border.all(
          color: borderColor ??
              (gradient == null ? AppColors.hairlineBorder : Colors.transparent),
        ),
        boxShadow: shadow ?? (elevated ? AppShadows.card() : null),
      ),
      child: child,
    );

    if (onTap == null) return surface;
    return Pressable(
      onTap: onTap!,
      borderRadius: br,
      child: surface,
    );
  }
}

/// A card filled with a gradient — used for hero/feature blocks.
class GradientCard extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;

  const GradientCard({
    super.key,
    required this.child,
    this.gradient = AppGradients.brand,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.margin,
    this.radius = AppRadius.lg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _dominant(gradient);
    final br = BorderRadius.circular(radius);
    final surface = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: br,
        boxShadow: AppShadows.glow(accent, strength: 0.30),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: child,
        ),
      ),
    );
    if (onTap == null) return surface;
    return Pressable(onTap: onTap!, borderRadius: br, child: surface);
  }

  static Color _dominant(Gradient g) {
    if (g is LinearGradient && g.colors.isNotEmpty) {
      return g.colors[g.colors.length > 1 ? 1 : 0];
    }
    return AppColors.primary;
  }
}

/// Frosted panel for content sitting on top of a gradient header.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.md),
    this.radius = AppRadius.md,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppGradients.glassOverlay(opacity: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22 * opacity)),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interaction
// ─────────────────────────────────────────────────────────────────────────────

/// Scales + haptics on press. Gives every tappable surface a bit of life.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final double scale;
  final bool haptic;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = AppRadius.brLg,
    this.scale = 0.975,
    this.haptic = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        if (widget.haptic) HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section headers
// ─────────────────────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? action;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.action,
    this.onAction,
    this.actionIcon = Icons.arrow_forward_rounded,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(), style: AppText.eyebrow),
                  const SizedBox(height: 3),
                ],
                Text(title, style: AppText.section),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (action != null && onAction != null)
            Pressable(
              onTap: onAction!,
              borderRadius: AppRadius.brPill,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action!,
                      style: AppText.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatars, pills, badges
// ─────────────────────────────────────────────────────────────────────────────

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  final Gradient? gradient;
  final bool ring;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.color,
    this.gradient,
    this.ring = false,
  });

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String s) =>
        s.isEmpty ? '' : String.fromCharCode(s.runes.first).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return '${first(parts.first)}${first(parts.last)}';
  }

  @override
  Widget build(BuildContext context) {
    final base = color ?? AppColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, Color.lerp(base, Colors.black, 0.22)!],
            ),
        border: ring
            ? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2)
            : null,
        boxShadow: AppShadows.glow(base, strength: 0.24),
      ),
      alignment: Alignment.center,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

enum PillTone { neutral, accent, success, warning, danger, info, inverse }

/// Small status pill — one consistent shape for every badge in the app.
class StatusPill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final IconData? icon;
  final Color? accentOverride;
  final bool dense;

  const StatusPill({
    super.key,
    required this.label,
    this.tone = PillTone.neutral,
    this.icon,
    this.accentOverride,
    this.dense = false,
  });

  ({Color bg, Color fg}) _colors() {
    switch (tone) {
      case PillTone.accent:
        final a = accentOverride ?? AppColors.primary;
        return (bg: a.withValues(alpha: 0.12), fg: a);
      case PillTone.success:
        return (bg: AppColors.successSoft, fg: AppColors.successDark);
      case PillTone.warning:
        return (bg: AppColors.warningSoft, fg: AppColors.warningDark);
      case PillTone.danger:
        return (bg: AppColors.dangerSoft, fg: AppColors.dangerDark);
      case PillTone.info:
        return (bg: AppColors.infoSoft, fg: Color(0xFF1D4ED8));
      case PillTone.inverse:
        return (bg: AppColors.ink, fg: Colors.white);
      case PillTone.neutral:
        return (bg: AppColors.surfaceContainerHigh, fg: AppColors.inkSoft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: c.fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.fg,
                fontSize: dense ? 10.5 : 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small numeric bubble, e.g. unread counts.
class CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const CountBadge({super.key, required this.count, this.color = AppColors.danger});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.18)!],
        ),
        borderRadius: AppRadius.brPill,
        boxShadow: AppShadows.glow(color, strength: 0.4),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / loading states
// ─────────────────────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.accent,
    this.padding = const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    final a = accent ?? AppColors.primary;
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [a.withValues(alpha: 0.16), a.withValues(alpha: 0.05)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: a.withValues(alpha: 0.14)),
            ),
            child: Icon(icon, size: 32, color: a),
          ).animate().scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: AppSpace.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.cardTitle.copyWith(fontSize: 15.5),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(fontSize: 13, color: AppColors.inkFaint),
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpace.md),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder block used while data loads.
class Skeleton extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  final bool circle;

  const Skeleton({
    super.key,
    this.height = 14,
    this.width,
    this.radius = AppRadius.sm,
  }) : circle = false;

  const Skeleton.circle({super.key, required double size})
      : height = size,
        width = size,
        radius = size / 2,
        circle = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1400.ms,
          color: Colors.white.withValues(alpha: 0.65),
        );
  }
}

/// Card-shaped skeleton used while a list of cards loads.
class SkeletonCard extends StatelessWidget {
  final int lines;
  final double height;

  const SkeletonCard({super.key, this.lines = 3, this.height = 0});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Skeleton.circle(size: 40),
            SizedBox(width: 12),
            Expanded(child: Skeleton(height: 12, width: 120)),
            SizedBox(width: 12),
            Skeleton(height: 12, width: 40),
          ],
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < lines; i++) ...[
          Skeleton(height: 11, width: i.isEven ? double.infinity : 180),
          const SizedBox(height: 9),
        ],
      ],
    );
    return AppCard(
      elevated: false,
      child: height > 0 ? SizedBox(height: height, child: content) : content,
    );
  }
}

/// Inline error with a retry affordance.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      accent: AppColors.danger,
      title: 'Something went wrong',
      message: message,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

/// Fades + slides children in sequence. Wrap a list of cards for a polished
/// first paint without hand-tuning per-screen animations.
class StaggeredList extends StatelessWidget {
  final int count;
  final Widget Function(int index) builder;
  final Duration step;

  const StaggeredList({
    super.key,
    required this.count,
    required this.builder,
    this.step = const Duration(milliseconds: 55),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < count; i++)
          builder(i)
              .animate(delay: AppMotion.stagger(i, step: step))
              .fadeIn(duration: 340.ms, curve: Curves.easeOut)
              .slideY(begin: 0.10, end: 0, duration: 380.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}
