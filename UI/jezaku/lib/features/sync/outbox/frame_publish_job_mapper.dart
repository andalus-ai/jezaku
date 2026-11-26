import 'dart:typed_data';

import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/outbox/frame_publisher.dart';

/// Turns a frame stored on this device into what the memory service expects.
abstract final class FramePublishJobMapper {
  static FramePublishJob fromMemory(
    AnchorMemory memory, {
    required String ownerId,
  }) {
    final meta = memory.captureMetadata;
    return FramePublishJob(
      memoryId: memory.id,
      ownerId: ownerId,
      visibility: memory.audience.wireName,
      // The service only knows geo, visual and hybrid. A frame hung in AR is
      // anchored by position and by what the camera saw.
      anchorType: memory.hasArExperience ? 'hybrid' : 'geo',
      latitude: memory.latitude,
      longitude: memory.longitude,
      frameStyle: memory.frameLookId,
      capturedAt: (memory.capturedAt ?? DateTime.now()).toUtc(),
      photo: photoOf(memory),
      caption: memory.caption,
      altitudeMeters: meta.altitudeMeters,
      headingDegrees: _heading(meta.headingDegrees),
      pitchDegrees: _within(meta.pitchDegrees, -90, 90),
      rollDegrees: _within(meta.rollDegrees, -180, 180),
      // The service rejects an accuracy outside 0.1 m - 10 km (0 included), so
      // such a value is left out instead of failing the whole frame.
      gpsAccuracyMeters: _within(meta.gpsAccuracyMeters, 0.1, 10000),
    );
  }

  /// The frame's photo, or null when it has none the media service accepts.
  static FramePhoto? photoOf(AnchorMemory memory) {
    final attachment = memory.mediaAttachment;
    final bytes = attachment?.bytes;
    if (attachment == null || bytes == null || bytes.isEmpty) {
      return null;
    }
    if (attachment.type == AnchorMediaType.arRecording ||
        attachment.type == AnchorMediaType.arModel) {
      return null;
    }
    final contentType = sniffImageContentType(bytes);
    if (contentType == null) {
      return null;
    }
    return FramePhoto(
      bytes: bytes,
      fileName: '${memory.id}.${_extensionOf(contentType)}',
      contentType: contentType,
    );
  }

  /// The image type named by the file's first bytes, or null when it is not a
  /// type the media service accepts.
  static String? sniffImageContentType(Uint8List bytes) {
    bool starts(List<int> prefix, {int at = 0}) {
      if (bytes.length < at + prefix.length) {
        return false;
      }
      for (var i = 0; i < prefix.length; i++) {
        if (bytes[at + i] != prefix[i]) {
          return false;
        }
      }
      return true;
    }

    if (starts(const [0xFF, 0xD8, 0xFF])) {
      return 'image/jpeg';
    }
    if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'image/png';
    }
    // RIFF....WEBP
    if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
        starts(const [0x57, 0x45, 0x42, 0x50], at: 8)) {
      return 'image/webp';
    }
    // ....ftypheic / heix / mif1 (HEIF family)
    if (starts(const [0x66, 0x74, 0x79, 0x70], at: 4) &&
        (starts(const [0x68, 0x65, 0x69], at: 8) ||
            starts(const [0x6D, 0x69, 0x66, 0x31], at: 8))) {
      return 'image/heic';
    }
    return null;
  }

  static String _extensionOf(String contentType) => switch (contentType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/heic' => 'heic',
        _ => 'jpg',
      };

  static double _heading(double degrees) {
    if (!degrees.isFinite) {
      return 0;
    }
    final wrapped = degrees % 360;
    return wrapped < 0 ? wrapped + 360 : wrapped;
  }

  static double? _within(double value, double min, double max) {
    if (!value.isFinite || value < min || value > max) {
      return null;
    }
    return value;
  }
}
