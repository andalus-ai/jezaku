import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_visual_frame_capturer.dart';

Future<ui.Image> _solid(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> _png(int width, int height, Color color) async {
  final image = await _solid(width, height, color);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Future<List<int>> _pixel(ui.Image image, int x, int y) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = data!.buffer.asUint8List();
  final offset = (y * image.width + x) * 4;
  return bytes.sublist(offset, offset + 4);
}

void main() {
  testWidgets('capturePng returns null without an overlay', (tester) async {
    await tester.runAsync(() async {
      final capturer = ARVisualFrameCapturer(
        captureOverlay: () async => null,
        captureCameraBytes: () async => Uint8List(0),
      );

      expect(await capturer.capturePng(), isNull);
    });
  });

  testWidgets('capturePng falls back to the overlay when camera is missing',
      (tester) async {
    await tester.runAsync(() async {
      for (final camera in <Future<Uint8List?> Function()>[
        () async => null,
        () async => Uint8List(0),
        () async => throw StateError('camera gone'),
        () async => Uint8List.fromList(<int>[1, 2, 3]),
      ]) {
        final capturer = ARVisualFrameCapturer(
          captureOverlay: () => _solid(6, 4, const Color(0xFF00FF00)),
          captureCameraBytes: camera,
        );

        final bytes = await capturer.capturePng();
        final decoded = await ARVisualFrameCapturer.decodeImage(bytes!);

        expect(decoded.width, 6);
        expect(decoded.height, 4);
        expect(await _pixel(decoded, 0, 0), <int>[0, 255, 0, 255]);
        decoded.dispose();
      }
    });
  });

  testWidgets('capturePng draws the overlay over the camera frame',
      (tester) async {
    await tester.runAsync(() async {
      final capturer = ARVisualFrameCapturer(
        captureOverlay: () async {
          // Transparent overlay with an opaque blue left half.
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawRect(
            const Rect.fromLTWH(0, 0, 4, 4),
            Paint()..color = const Color(0xFF0000FF),
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(4, 4);
          picture.dispose();
          return image;
        },
        captureCameraBytes: () => _png(8, 2, const Color(0xFFFF0000)),
      );

      final bytes = await capturer.capturePng();
      final decoded = await ARVisualFrameCapturer.decodeImage(bytes!);

      // Output takes the overlay size, overlay covers the camera frame.
      expect(decoded.width, 4);
      expect(decoded.height, 4);
      expect(await _pixel(decoded, 2, 2), <int>[0, 0, 255, 255]);
      decoded.dispose();
    });
  });

  testWidgets('compose cover-fits the camera under a transparent overlay',
      (tester) async {
    await tester.runAsync(() async {
      final camera = await _solid(8, 2, const Color(0xFFFF0000));
      final overlay = await _solid(4, 4, const Color(0x00000000));

      final composed = await ARVisualFrameCapturer.compose(
        cameraImage: camera,
        overlayImage: overlay,
      );

      expect(composed.width, 4);
      expect(composed.height, 4);
      expect(await _pixel(composed, 0, 0), <int>[255, 0, 0, 255]);
      expect(await _pixel(composed, 3, 3), <int>[255, 0, 0, 255]);
      composed.dispose();
      camera.dispose();
      overlay.dispose();
    });
  });
}
