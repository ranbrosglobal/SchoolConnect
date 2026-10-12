import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';

/// Role-aware hero header.
///
/// Rounds off the bottom, carries the role's gradient, and paints two soft
/// radial highlights so the surface never reads as a flat fill. An optional
/// [child] is embedded inside the gradient — that is where "hero metric"
/// cards live, and it keeps the top of every screen feeling custom rather
/// than templated.
class GradientHeader extends StatelessWidget {
  final AppRoleStyle role;
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? child;
  final bool showBack;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;
  final double bottomRadius;

  const GradientHeader({
    super.key,
    this.role = AppRoleStyle.student,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.child,
    this.showBack = false,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 22),
    this.bottomRadius = AppRadius.xxl,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
      child: Container(
        decoration: BoxDecoration(
          gradient: role.gradient,
          boxShadow: AppShadows.glow(_dominant(role.gradient), strength: 0.28),
        ),
        child: Stack(
          children: [
            // Soft light blooms — keeps the gradient from looking flat.
            Positioned(
              top: -70,
              right: -40,
              child: _blob(190, Colors.white.withValues(alpha: 0.16)),
            ),
            Positioned(
              bottom: -80,
              left: -50,
              child: _blob(210, role.accentLight.withValues(alpha: 0.22)),
            ),
            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (showBack)
                          _GlassIconButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: onBack ?? () => Navigator.maybePop(context),
                          ),
                        if (leading != null) ...[
                          if (showBack) const SizedBox(width: 10),
                          leading!,
                        ],
                        const Spacer(),
                        for (final a in actions) ...[
                          a,
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    if (leading != null || showBack || actions.isNotEmpty)
                      const SizedBox(height: AppSpace.md),
                    if (eyebrow != null) ...[
                      Text(
                        eyebrow!.toUpperCase(),
                        style: AppText.eyebrow.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      title,
                      style: AppText.display.copyWith(color: Colors.white, fontSize: 27),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        style: AppText.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                    if (child != null) ...[
                      const SizedBox(height: AppSpace.lg),
                      child!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );

  static Color _dominant(Gradient g) {
    if (g is LinearGradient && g.colors.length > 1) return g.colors[1];
    return AppColors.primary;
  }
}

/// A frosted circular icon button designed for use on gradients.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  const _GlassIconButton({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
        if (badge != null && badge! > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: AppRadius.brPill,
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              alignment: Alignment.center,
              child: Text(
                badge! > 9 ? '9+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Public glass icon button so screens can add their own header actions.
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;
  final String? tooltip;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = _GlassIconButton(icon: icon, onTap: onTap, badge: badge);
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Slow-drifting mesh background. Cheap enough for full-screen pages because
/// it is a single static paint of soft radial blobs (no blur filters).
class AuroraBackground extends StatelessWidget {
  final Widget child;
  final Color tint;
  final bool animate;

  const AuroraBackground({
    super.key,
    required this.child,
    this.tint = AppColors.primary,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: AppColors.background),
        ),
        Positioned(
          top: -140,
          right: -100,
          child: _blob(320, tint.withValues(alpha: 0.18)),
        ),
        Positioned(
          bottom: -160,
          left: -120,
          child: _blob(340, AppColors.secondary.withValues(alpha: 0.13)),
        ),
        Positioned(
          top: 180,
          left: -90,
          child: _blob(240, AppColors.tertiary.withValues(alpha: 0.10)),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  static Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}

/// Small helper so callers can grab an "accent light" from a role style.
extension RoleStyleExtras on AppRoleStyle {
  Color get accentLight => accentSoft;
}
