import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import 'foundation.dart';

/// Animated number that counts up to [value] on first paint.
///
/// Gives metrics a sense of "live data" for a fraction of a second — a cheap,
/// high-impact detail on dashboards.
class AnimatedCounter extends StatelessWidget {
  final num value;
  final int decimals;
  final TextStyle? style;
  final String? suffix;
  final String? prefix;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.decimals = 0,
    this.style,
    this.suffix,
    this.prefix,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final text = v.toStringAsFixed(decimals);
        return Text(
          '${prefix ?? ''}$text${suffix ?? ''}',
          style: style ?? AppText.metric,
        );
      },
    );
  }
}

/// Circular progress ring with a gradient sweep and optional center child.
class ProgressRing extends StatelessWidget {
  final double percent; // 0..100
  final double size;
  final double stroke;
  final Gradient gradient;
  final Widget? center;
  final Color trackColor;

  const ProgressRing({
    super.key,
    required this.percent,
    this.size = 84,
    this.stroke = 9,
    this.gradient = AppGradients.brand,
    this.center,
    this.trackColor = AppColors.surfaceContainerHigh,
  });

  static Gradient gradientFor(double percent) {
    if (percent >= 85) return AppGradients.mint;
    if (percent >= 70) return AppGradients.brand;
    if (percent >= 50) return AppGradients.amber;
    return AppGradients.rose;
  }

  @override
  Widget build(BuildContext context) {
    final target = (percent.clamp(0, 100)) / 100;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: v,
                  stroke: stroke,
                  gradient: gradient,
                  track: trackColor,
                ),
              ),
              if (center != null) center!,
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double stroke;
  final Gradient gradient;
  final Color track;

  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.gradient,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);

    if (progress <= 0) return;
    final sweep = math.pi * 2 * progress;
    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.stroke != stroke || old.track != track;
}

/// Horizontal progress bar with a gradient fill.
class GradientBar extends StatelessWidget {
  final double percent;
  final double height;
  final Gradient gradient;
  final Color trackColor;
  final double radius;

  const GradientBar({
    super.key,
    required this.percent,
    this.height = 8,
    this.gradient = AppGradients.brand,
    this.trackColor = AppColors.surfaceContainerHigh,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final target = (percent.clamp(0, 100)) / 100;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Container(height: height, color: trackColor),
            FractionallySizedBox(
              widthFactor: v.clamp(0.0, 1.0),
              child: Container(
                height: height,
                decoration: BoxDecoration(gradient: gradient),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact bar chart. No chart package needed — just a painter that scales to
/// whatever container it lands in.
class MiniBarChart extends StatelessWidget {
  final List<double> values;
  final double height;
  final Gradient gradient;
  final List<String>? labels;
  final Color? labelColor;

  const MiniBarChart({
    super.key,
    required this.values,
    this.height = 72,
    this.gradient = AppGradients.brand,
    this.labels,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(height: height);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => CustomPaint(
              painter: _BarsPainter(values: values, progress: v, gradient: gradient),
            ),
          ),
        ),
        if (labels != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              for (int i = 0; i < labels!.length; i++)
                Expanded(
                  child: Text(
                    labels![i],
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(
                      fontSize: 10,
                      color: labelColor ?? AppColors.inkFaint,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final double progress;
  final Gradient gradient;

  _BarsPainter({
    required this.values,
    required this.progress,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce(math.max);
    final safeMax = maxV <= 0 ? 1.0 : maxV;
    final n = values.length;
    final gap = n > 12 ? 2.0 : 6.0;
    final barW = (size.width - gap * (n - 1)) / n;
    final rect = Offset.zero & size;

    for (int i = 0; i < n; i++) {
      final t = (values[i] / safeMax) * progress;
      final h = math.max(3.0, size.height * t.clamp(0.0, 1.0));
      final left = i * (barW + gap);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - h, barW, h),
        Radius.circular(math.min(barW / 2, 5)),
      );
      final paint = Paint()..shader = gradient.createShader(rect);
      canvas.drawRRect(r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.progress != progress || old.values != values;
}

/// Smooth area sparkline for trend lines (attendance over time, score drift).
class Sparkline extends StatelessWidget {
  final List<double> values;
  final double height;
  final Color color;
  final bool fill;

  const Sparkline({
    super.key,
    required this.values,
    this.height = 56,
    this.color = AppColors.primary,
    this.fill = true,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _SparkPainter(values: values, progress: v, color: color, fill: fill),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final double progress;
  final Color color;
  final bool fill;

  _SparkPainter({
    required this.values,
    required this.progress,
    required this.color,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final norm = (values[i] - minV) / range;
      final y = size.height - norm * size.height * 0.86 - size.height * 0.07;
      final x = dx * i;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = dx * (i - 1);
        final prevNorm = (values[i - 1] - minV) / range;
        final prevY = size.height - prevNorm * size.height * 0.86 - size.height * 0.07;
        final cx = (prevX + x) / 2;
        path.cubicTo(cx, prevY, cx, y, x, y);
      }
    }

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.26), color.withValues(alpha: 0.0)],
          ).createShader(Offset.zero & size),
      );
    }

    // Reveal the stroke progressively.
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.progress != progress || old.values != values || old.color != color;
}

/// A week/month attendance heat strip — a neat way to show daily status.
class HeatStrip extends StatelessWidget {
  final List<({String label, String status})> days;
  final double cellSize;

  const HeatStrip({super.key, required this.days, this.cellSize = 30});

  static Color _tone(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return AppColors.success;
      case 'absent':
        return AppColors.danger;
      case 'leave':
        return AppColors.warning;
      case 'half day':
        return AppColors.info;
      default:
        return AppColors.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final d in days)
          Tooltip(
            message: '${d.label} · ${d.status}',
            child: Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: _tone(d.status).withValues(alpha: 0.16),
                borderRadius: AppRadius.brXs,
                border: Border.all(
                  color: _tone(d.status).withValues(alpha: 0.35),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                d.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: _tone(d.status),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Big metric tile: label, value, optional delta and trailing icon art.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? delta;
  final bool deltaPositive;
  final VoidCallback? onTap;
  final bool compact;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppColors.primary,
    this.delta,
    this.deltaPositive = true,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: compact ? 30 : 36,
              height: compact ? 30 : 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(icon, size: compact ? 16 : 18, color: accent),
            ),
            const Spacer(),
            if (delta != null)
              Flexible(
                child: StatusPill(
                  label: delta!,
                  tone: deltaPositive ? PillToneFor.up : PillToneFor.down,
                  dense: true,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          value,
          style: AppText.metric.copyWith(fontSize: compact ? 21 : 25),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppText.caption.copyWith(fontSize: 11.5),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? AppSpace.sm : AppSpace.md),
      child: body,
    );
  }
}

/// Helper so callers can say `deltaPositive: true` without importing PillTone.
class PillToneFor {
  static const up = PillTone.success;
  static const down = PillTone.danger;
}
