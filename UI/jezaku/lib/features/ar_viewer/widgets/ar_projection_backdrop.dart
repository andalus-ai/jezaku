import 'package:material_ui/material_ui.dart';

/// The dark "no camera" background of the AR viewer with a status line and,
/// when something can be done about it, a button.
///
/// It stands in for the camera while permission is asked for, the session
/// starts, or something went wrong, so each of those says what is happening
/// instead of showing a blank screen.
class ARProjectionBackdrop extends StatelessWidget {
  const ARProjectionBackdrop({
    required this.statusLabel,
    this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String statusLabel;

  /// Longer explanation under the status line.
  final String? message;

  /// The button's text. The button is drawn only with both this and
  /// [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF111827),
            Color(0xFF0F172A),
            Color(0xFF020617),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: ARReticlePainter()),
          ),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_in_ar, color: Colors.white54, size: 96),
                SizedBox(height: 12),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 128),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusLabel,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        message!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The faint rings and cross-hair drawn over the camera (and the backdrop).
class ARReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (final radius in [72.0, 140.0, 220.0]) {
      canvas.drawCircle(center, radius, paint);
    }
    canvas.drawLine(
      Offset(center.dx - 26, center.dy),
      Offset(center.dx + 26, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 26),
      Offset(center.dx, center.dy + 26),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
