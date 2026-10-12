import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';

/// The copilot orb. Pulsing halo + gradient core so the assistant feels like
/// a presence in the app rather than a chat icon.
class AssistantOrb extends StatelessWidget {
  final double size;
  final bool thinking;
  final IconData icon;

  const AssistantOrb({
    super.key,
    this.size = 40,
    this.thinking = false,
    this.icon = Icons.auto_awesome_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.ai,
        boxShadow: AppShadows.glow(AppColors.primary, strength: 0.36),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );

    return SizedBox(
      width: size * 1.6,
      height: size * 1.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer halo, always breathing.
          Container(
            width: size * 1.5,
            height: size * 1.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.tertiary.withValues(alpha: 0.30),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.86, 0.86),
                end: const Offset(1.06, 1.06),
                duration: thinking ? 900.ms : 2200.ms,
                curve: Curves.easeInOut,
              ),
          core,
        ],
      ),
    );
  }
}

/// Three-dot "composing" indicator.
class TypingDots extends StatelessWidget {
  final Color color;
  final double dotSize;

  const TypingDots({super.key, this.color = AppColors.primary, this.dotSize = 7});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .fadeIn(delay: (i * 140).ms, duration: 260.ms)
            .then()
            .fadeOut(duration: 260.ms)
            .then()
            .fadeIn(duration: 260.ms);
      }),
    );
  }
}

/// A short label that reads like the model narrating its own work.
/// Purely presentational — the caller supplies the text.
class ThinkingStrip extends StatelessWidget {
  final String text;

  const ThinkingStrip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TypingDots(dotSize: 5),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: AppText.caption.copyWith(
              color: AppColors.primary,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Small AI attribution chip, e.g. under an assistant reply.
class AiTag extends StatelessWidget {
  final String label;

  const AiTag({super.key, this.label = 'School Connect AI'});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.ai,
          ),
          child: const Icon(Icons.auto_awesome_rounded, size: 8, color: Colors.white),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppText.caption.copyWith(fontSize: 10, letterSpacing: 0.2),
        ),
      ],
    );
  }
}
