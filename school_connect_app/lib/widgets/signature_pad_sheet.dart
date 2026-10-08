import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One continuous stroke drawn by the signer.
class _Stroke {
  final List<Offset> points = [];
}

/// Signature pad modal — the in-app version of the "Sign Report" screen from
/// the school's handwritten e-signature spec: an authorised person draws
/// their signature with a finger, stylus or mouse, can Clear and redraw,
/// and Confirm returns transparent-background PNG bytes of the ink.
///
/// Returns `null` when the user dismisses without confirming.
Future<Uint8List?> showSignaturePadSheet(
  BuildContext context, {
  String title = 'Sign Report',
}) {
  return showModalBottomSheet<Uint8List?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => const _SignaturePadSheet(),
  );
}

class _SignaturePadSheet extends StatefulWidget {
  const _SignaturePadSheet();

  @override
  State<_SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<_SignaturePadSheet> {
  final List<_Stroke> _strokes = [];
  _Stroke? _active;
  final GlobalKey _canvasKey = GlobalKey();

  bool get _hasInk => _strokes.any((s) => s.points.length > 1);

  // ------------------------------------------------------------------
  // Capture
  // ------------------------------------------------------------------

  /// Rasterizes the drawn strokes to a cropped transparent PNG.
  Future<Uint8List?> _rasterize() async {
    final box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_hasInk) return null;

    // Bounds of the ink, with padding, clamped to the canvas.
    double minX = double.infinity,
        minY = double.infinity,
        maxX = double.negativeInfinity,
        maxY = double.negativeInfinity;
    for (final stroke in _strokes) {
      for (final p in stroke.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    const pad = 12.0;
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final canvasSize = box.size;

    final cropLeft = (minX - pad).clamp(0.0, canvasSize.width);
    final cropTop = (minY - pad).clamp(0.0, canvasSize.height);
    final cropRight = (maxX + pad).clamp(0.0, canvasSize.width);
    final cropBottom = (maxY + pad).clamp(0.0, canvasSize.height);
    final cropW = (cropRight - cropLeft).clamp(1.0, canvasSize.width);
    final cropH = (cropBottom - cropTop).clamp(1.0, canvasSize.height);

    // Cap resolution for large canvases / high-dpr screens.
    const maxLongEdge = 1200.0;
    final scale = (maxLongEdge / (cropW > cropH ? cropW : cropH))
        .clamp(0.0, dpr == 0 ? 1.0 : dpr);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.translate(-cropLeft, -cropTop);

    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in _strokes) {
      if (stroke.points.isEmpty) continue;
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final p in stroke.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final pxW = (cropW * scale).round().clamp(1, 4096);
    final pxH = (cropH * scale).round().clamp(1, 4096);
    final image = await picture.toImage(pxW, pxH);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  Future<void> _confirm() async {
    final bytes = await _rasterize();
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Draw a signature first')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(bytes);
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.draw_rounded,
                      color: Color(0xFF1E3A8A), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Sign Report',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Draw your signature below, then confirm to embed it in the PDF.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: GestureDetector(
                    onPanStart: (d) {
                      final local = _canvasLocal(d.localPosition);
                      if (local == null) return;
                      setState(() {
                        _active = _Stroke()..points.add(local);
                        _strokes.add(_active!);
                      });
                    },
                    onPanUpdate: (d) {
                      final local = _canvasLocal(d.localPosition);
                      if (local == null || _active == null) return;
                      setState(() => _active!.points.add(local));
                    },
                    onPanEnd: (_) => setState(() => _active = null),
                    onPanCancel: () => setState(() => _active = null),
                    child: CustomPaint(
                      key: _canvasKey,
                      painter: _SignaturePainter(strokes: _strokes),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _hasInk ? '' : 'Sign here with your finger, stylus or mouse',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _hasInk ? () => setState(() => _strokes.clear()) : null,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                      ),
                      onPressed: _hasInk ? _confirm : null,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Confirm Signature'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Clamps the gesture position to the canvas — a drag that strays outside
  /// shouldn't add points far off-canvas.
  Offset? _canvasLocal(Offset local) {
    final box =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final size = box.size;
    if (local.dx < 0 || local.dy < 0) return null;
    if (local.dx > size.width || local.dy > size.height) return null;
    return local;
  }
}

class _SignaturePainter extends CustomPainter {
  final List<_Stroke> strokes;
  _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      if (stroke.points.length == 1) {
        // A dot.
        final dot = Paint()
          ..color = paint.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(stroke.points.single, paint.strokeWidth / 2, dot);
        continue;
      }
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final p in stroke.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    // Signature rule line, like a paper register.
    final line = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(24, size.height - 28),
      Offset(size.width - 24, size.height - 28),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
