import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';

class SafeCapturePreviewService {
  const SafeCapturePreviewService();

  Future<Uint8List?> renderPreview({
    required CaptureSensorSnapshot snapshot,
    required DateTime capturedAt,
    Size size = const Size(720, 960),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Offset.zero & size;
    final center = rect.center;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          const [
            Color(0xFF07111F),
            Color(0xFF10293A),
            Color(0xFF05070D),
          ],
          const [0, 0.55, 1],
        ),
    );

    _drawGrid(canvas, size);
    _drawReticle(canvas, center);
    _drawCompass(canvas, center, snapshot.headingDegrees);
    _drawFooter(canvas, size, snapshot, capturedAt);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.5;
    for (final fraction in const [1 / 3, 2 / 3]) {
      canvas.drawLine(
        Offset(size.width * fraction, 0),
        Offset(size.width * fraction, size.height),
        linePaint,
      );
      canvas.drawLine(
        Offset(0, size.height * fraction),
        Offset(size.width, size.height * fraction),
        linePaint,
      );
    }
  }

  void _drawReticle(Canvas canvas, Offset center) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.42);
    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF5EEAD4);

    canvas.drawCircle(center, 118, ringPaint);
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xFF5EEAD4));
    canvas.drawLine(center + const Offset(-170, 0),
        center + const Offset(-112, 0), accentPaint);
    canvas.drawLine(center + const Offset(112, 0),
        center + const Offset(170, 0), accentPaint);
    canvas.drawLine(center + const Offset(0, -170),
        center + const Offset(0, -112), accentPaint);
    canvas.drawLine(center + const Offset(0, 112),
        center + const Offset(0, 170), accentPaint);
  }

  void _drawCompass(Canvas canvas, Offset center, double headingDegrees) {
    if (!headingDegrees.isFinite) {
      return;
    }
    final headingRadians = (headingDegrees - 90) * math.pi / 180;
    final tip = center +
        Offset(math.cos(headingRadians), math.sin(headingRadians)) * 92;
    final tail = center -
        Offset(math.cos(headingRadians), math.sin(headingRadians)) * 42;
    final paint = Paint()
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFDE68A);
    canvas.drawLine(tail, tip, paint);
    canvas.drawCircle(tip, 10, Paint()..color = const Color(0xFFFDE68A));
  }

  void _drawFooter(
    Canvas canvas,
    Size size,
    CaptureSensorSnapshot snapshot,
    DateTime capturedAt,
  ) {
    final panelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(48, size.height - 338, size.width - 96, 250),
      const Radius.circular(32),
    );
    canvas.drawRRect(
      panelRect,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );
    canvas.drawRRect(
      panelRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    _drawText(
      canvas,
      'JEJAKU SAFE CAPTURE',
      Offset(84, size.height - 306),
      fontSize: 30,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    );
    _drawText(
      canvas,
      _formatCapturedAt(capturedAt),
      Offset(size.width - 330, size.height - 304),
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: Colors.white70,
      maxWidth: 250,
      textAlign: TextAlign.right,
    );

    _drawMetric(
      canvas,
      'LAT/LONG',
      snapshot.locationLabel,
      Offset(84, size.height - 238),
    );
    _drawMetric(
      canvas,
      'ALTITUDE',
      snapshot.altitudeLabel,
      Offset(84, size.height - 160),
    );
    _drawMetric(
      canvas,
      'DIRECTION',
      snapshot.compassLabel,
      Offset(size.width * 0.52, size.height - 238),
    );
    _drawMetric(
      canvas,
      'ACCURACY',
      snapshot.accuracyLabel,
      Offset(size.width * 0.52, size.height - 160),
    );
  }

  void _drawMetric(
    Canvas canvas,
    String label,
    String value,
    Offset offset,
  ) {
    _drawText(
      canvas,
      label,
      offset,
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF93C5FD),
    );
    _drawText(
      canvas,
      value,
      offset + const Offset(0, 28),
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      maxWidth: 430,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double maxWidth = 500,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0,
        ),
      ),
      maxLines: 1,
      ellipsis: '...',
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  String _formatCapturedAt(DateTime capturedAt) {
    final local = capturedAt.toLocal();
    return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
