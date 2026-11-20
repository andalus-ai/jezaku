import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Composes the AR camera snapshot and the Flutter overlay into a single PNG
/// frame for screen recording and snapshots.
///
/// The sources are injected so the class has no knowledge of widgets, render
/// boundaries or the native AR controller.
class ARVisualFrameCapturer {
  const ARVisualFrameCapturer({
    required this.captureOverlay,
    required this.captureCameraBytes,
  });

  /// Renders the Flutter overlay layer. Ownership of the image passes to the
  /// capturer, which disposes it.
  final Future<ui.Image?> Function() captureOverlay;

  /// Returns an encoded snapshot of the native camera feed, if available.
  final Future<Uint8List?> Function() captureCameraBytes;

  /// Captures one frame as PNG bytes, or `null` when the overlay is not
  /// available. Falls back to the overlay alone when no camera frame exists,
  /// unless [requireCamera] is set: a photo of a memory must show the camera
  /// feed, so it returns `null` instead of an overlay-only image.
  Future<Uint8List?> capturePng({bool requireCamera = false}) async {
    final overlayImage = await captureOverlay();
    if (overlayImage == null) {
      return null;
    }
    ui.Image? cameraImage;
    ui.Image? composedImage;
    try {
      cameraImage = await _decodeCamera();
      if (requireCamera && cameraImage == null) {
        return null;
      }
      final outputImage = cameraImage == null
          ? overlayImage
          : await compose(
              cameraImage: cameraImage,
              overlayImage: overlayImage,
            );
      if (!identical(outputImage, overlayImage)) {
        composedImage = outputImage;
      }
      final data = await outputImage.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      composedImage?.dispose();
      cameraImage?.dispose();
      overlayImage.dispose();
    }
  }

  Future<ui.Image?> _decodeCamera() async {
    try {
      final bytes = await captureCameraBytes();
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      return await decodeImage(bytes);
    } on Object {
      return null;
    }
  }

  static Future<ui.Image> decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  /// Draws [cameraImage] cover-fitted to the overlay size, then the overlay on
  /// top. The output has the overlay's pixel dimensions.
  static Future<ui.Image> compose({
    required ui.Image cameraImage,
    required ui.Image overlayImage,
  }) async {
    final width = overlayImage.width;
    final height = overlayImage.height;
    final outputRect = Offset.zero & Size(width.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final sourceSize = Size(
      cameraImage.width.toDouble(),
      cameraImage.height.toDouble(),
    );
    final fitted = applyBoxFit(BoxFit.cover, sourceSize, outputRect.size);
    final sourceRect =
        Alignment.center.inscribe(fitted.source, Offset.zero & sourceSize);
    final destinationRect =
        Alignment.center.inscribe(fitted.destination, outputRect);

    canvas
      ..drawImageRect(cameraImage, sourceRect, destinationRect, Paint())
      ..drawImageRect(overlayImage, outputRect, outputRect, Paint());
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }
}
