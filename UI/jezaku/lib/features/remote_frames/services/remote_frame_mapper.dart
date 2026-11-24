import 'dart:typed_data';

import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';

/// Turns a frame from the memory service into the [AnchorMemory] the AR
/// viewer already knows how to draw.
///
/// The result is a view of someone else's frame: it carries the owner's id and
/// the service's audience, so the same visibility rules apply to it as to any
/// frame. It is never written to local storage or queued for upload.
class RemoteFrameMapper {
  const RemoteFrameMapper._();

  static AnchorMemory toAnchorMemory(
    RemoteFrame frame, {
    Uint8List? thumbnailBytes,
    DateTime? now,
  }) {
    final caption = frame.caption.trim();
    return AnchorMemory(
      id: frame.id,
      title: caption.isEmpty ? 'Frame' : caption,
      caption: caption,
      distanceLabel: _distanceLabel(frame.distanceMeters),
      capturedAgo: _agoLabel(frame.capturedAt, now ?? DateTime.now()),
      locationLabel: 'Nearby',
      latitude: frame.latitude,
      longitude: frame.longitude,
      reactions: 0,
      capturedAt: frame.capturedAt,
      captureMetadata: AnchorCaptureMetadata(
        altitudeMeters: frame.altitudeMeters ?? 0,
        headingDegrees: frame.headingDegrees ?? 0,
        pitchDegrees: 0,
        rollDegrees: 0,
        gpsAccuracyMeters: 0,
        anchorType: 'remote',
        captureSource: 'remote',
      ),
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.cameraPhoto,
        mediaId: frame.mediaId,
        bytes: thumbnailBytes,
      ),
      moderationStatus: _moderation(frame.moderationStatus),
      audience: frame.audience,
      ownerId: frame.ownerId,
    );
  }

  /// Only an explicit "approved" is shown. Missing or unknown values hide the
  /// frame, so a state this build does not understand fails closed.
  static AnchorModerationStatus _moderation(String? value) {
    return switch (value?.toLowerCase()) {
      'approved' => AnchorModerationStatus.approved,
      'flagged' => AnchorModerationStatus.flagged,
      _ => AnchorModerationStatus.hidden,
    };
  }

  static String _distanceLabel(double? meters) {
    if (meters == null) {
      return 'Nearby';
    }
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  static String _agoLabel(DateTime? at, DateTime now) {
    if (at == null) {
      return 'Earlier';
    }
    final age = now.difference(at);
    if (age.inMinutes < 1) {
      return 'Just now';
    }
    if (age.inHours < 1) {
      return '${age.inMinutes} min ago';
    }
    if (age.inDays < 1) {
      return '${age.inHours} h ago';
    }
    return '${age.inDays} d ago';
  }
}
