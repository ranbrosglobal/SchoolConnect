import 'package:flutter/material.dart';

/// Hand-drawn style icons. Drawn on a 24×24 grid with round strokes and a
/// soft tinted blob behind each shape, so they read as friendly doodles for
/// kids and adults alike while staying sharp at nav sizes.
enum DoodleKind {
  home,
  classes,
  calendar,
  profile,
  sparkle,
  assignment,
  people,
  check,
  chart,
  bell,
  star,
}

class DoodleIcon extends StatelessWidget {
  final DoodleKind kind;
  final double size;
  final Color color;

  /// Fills the doodle with a soft tint of [color]. Used for the selected state.
  final bool filled;

  const DoodleIcon({
    super.key,
    required this.kind,
    required this.color,
    this.size = 24,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DoodlePainter(kind: kind, color: color, filled: filled),
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final DoodleKind kind;
  final Color color;
  final bool filled;

  const _DoodlePainter({
    required this.kind,
    required this.color,
    required this.filled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final blob = Paint()
      ..color = color.withValues(alpha: filled ? 0.28 : 0.14)
      ..style = PaintingStyle.fill;
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draws the tinted blob first, then the outline on top.
    void shape(Path path) {
      canvas.drawPath(path, blob);
      canvas.drawPath(path, stroke);
    }

    RRect rr(double l, double t, double w, double h, double r) =>
        RRect.fromRectAndRadius(
            Rect.fromLTWH(l, t, w, h), Radius.circular(r));

    switch (kind) {
      case DoodleKind.home:
        shape(Path()
          ..moveTo(4, 11)
          ..lineTo(12, 4)
          ..lineTo(20, 11)
          ..lineTo(20, 19)
          ..quadraticBezierTo(20, 20, 19, 20)
          ..lineTo(5, 20)
          ..quadraticBezierTo(4, 20, 4, 19)
          ..close());
        canvas.drawPath(
            Path()
              ..moveTo(10, 20)
              ..lineTo(10, 15)
              ..lineTo(14, 15)
              ..lineTo(14, 20),
            stroke);
        break;

      case DoodleKind.classes:
        canvas.drawRRect(rr(4.5, 4, 15, 16, 3), blob);
        canvas.drawRRect(rr(4.5, 4, 15, 16, 3), stroke);
        canvas.drawLine(const Offset(9, 4), const Offset(9, 20), stroke);
        canvas.drawLine(const Offset(12, 8.5), const Offset(16.5, 8.5), stroke);
        canvas.drawLine(const Offset(12, 12.5), const Offset(16.5, 12.5), stroke);
        break;

      case DoodleKind.calendar:
        canvas.drawRRect(rr(3.5, 5.5, 17, 15, 4), blob);
        canvas.drawRRect(rr(3.5, 5.5, 17, 15, 4), stroke);
        canvas.drawLine(const Offset(3.5, 10), const Offset(20.5, 10), stroke);
        canvas.drawLine(const Offset(8, 3), const Offset(8, 7), stroke);
        canvas.drawLine(const Offset(16, 3), const Offset(16, 7), stroke);
        for (final x in [8.0, 12.0, 16.0]) {
          canvas.drawCircle(Offset(x, 15), 1.2, dot);
        }
        break;

      case DoodleKind.profile:
        canvas.drawCircle(const Offset(12, 8.5), 4, blob);
        canvas.drawCircle(const Offset(12, 8.5), 4, stroke);
        shape(Path()
          ..moveTo(4.5, 20.5)
          ..quadraticBezierTo(4.5, 13.5, 12, 13.5)
          ..quadraticBezierTo(19.5, 13.5, 19.5, 20.5)
          ..close());
        break;

      case DoodleKind.sparkle:
        shape(Path()
          ..moveTo(12, 3)
          ..quadraticBezierTo(13, 10, 21, 12)
          ..quadraticBezierTo(13, 14, 12, 21)
          ..quadraticBezierTo(11, 14, 3, 12)
          ..quadraticBezierTo(11, 10, 12, 3)
          ..close());
        canvas.drawCircle(const Offset(19.5, 4.5), 1.4, dot);
        canvas.drawCircle(const Offset(4.5, 19), 1.1, dot);
        break;

      case DoodleKind.assignment:
        canvas.drawRRect(rr(5, 4.5, 14, 16, 3), blob);
        canvas.drawRRect(rr(5, 4.5, 14, 16, 3), stroke);
        canvas.drawRRect(rr(9, 2.5, 6, 4, 1.5), blob);
        canvas.drawRRect(rr(9, 2.5, 6, 4, 1.5), stroke);
        canvas.drawLine(const Offset(8.5, 12), const Offset(15.5, 12), stroke);
        canvas.drawLine(const Offset(8.5, 16), const Offset(13, 16), stroke);
        break;

      case DoodleKind.people:
        canvas.drawCircle(const Offset(9, 8.5), 3.2, blob);
        canvas.drawCircle(const Offset(9, 8.5), 3.2, stroke);
        canvas.drawCircle(const Offset(16.5, 9.5), 2.6, stroke);
        canvas.drawPath(
            Path()
              ..moveTo(3, 20)
              ..quadraticBezierTo(3, 13.5, 9, 13.5)
              ..quadraticBezierTo(15, 13.5, 15, 20),
            stroke);
        canvas.drawPath(
            Path()
              ..moveTo(15.5, 14)
              ..quadraticBezierTo(20.5, 14.2, 21, 20),
            stroke);
        break;

      case DoodleKind.check:
        canvas.drawCircle(const Offset(12, 12), 9, blob);
        canvas.drawCircle(const Offset(12, 12), 9, stroke);
        canvas.drawPath(
            Path()
              ..moveTo(7.8, 12.4)
              ..lineTo(10.9, 15.4)
              ..lineTo(16.4, 9.2),
            stroke);
        break;

      case DoodleKind.chart:
        canvas.drawLine(const Offset(4, 20), const Offset(20, 20), stroke);
        canvas.drawRRect(rr(5.5, 13, 3.5, 7, 1.2), blob);
        canvas.drawRRect(rr(5.5, 13, 3.5, 7, 1.2), stroke);
        canvas.drawRRect(rr(10.5, 9, 3.5, 11, 1.2), blob);
        canvas.drawRRect(rr(10.5, 9, 3.5, 11, 1.2), stroke);
        canvas.drawRRect(rr(15.5, 5, 3.5, 15, 1.2), blob);
        canvas.drawRRect(rr(15.5, 5, 3.5, 15, 1.2), stroke);
        break;

      case DoodleKind.bell:
        shape(Path()
          ..moveTo(6, 16.5)
          ..lineTo(6, 11)
          ..quadraticBezierTo(6, 6, 12, 6)
          ..quadraticBezierTo(18, 6, 18, 11)
          ..lineTo(18, 16.5)
          ..lineTo(20, 18.5)
          ..lineTo(4, 18.5)
          ..close());
        canvas.drawCircle(const Offset(12, 20.5), 1.6, dot);
        break;

      case DoodleKind.star:
        shape(Path()
          ..moveTo(12, 3)
          ..lineTo(14.6, 9)
          ..lineTo(21, 9.5)
          ..lineTo(16.1, 13.6)
          ..lineTo(17.6, 20)
          ..lineTo(12, 16.6)
          ..lineTo(6.4, 20)
          ..lineTo(7.9, 13.6)
          ..lineTo(3, 9.5)
          ..lineTo(9.4, 9)
          ..close());
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) =>
      old.kind != kind || old.color != color || old.filled != filled;
}
