import 'package:jejaku/features/home/models/frame_audience.dart';

/// A frame as the memory service describes it: someone's photo hung at a
/// place. This is the wire model only; turning it into something the AR
/// viewer shows is a separate step.
class RemoteFrame {
  const RemoteFrame({
    required this.id,
    required this.ownerId,
    required this.latitude,
    required this.longitude,
    required this.audience,
    required this.distanceMeters,
    this.caption = '',
    this.mediaId,
    this.thumbnailUrl,
    this.mediaUrl,
    this.altitudeMeters,
    this.headingDegrees,
    this.mediaStatus,
    this.moderationStatus,
    this.capturedAt,
    this.frameStyle,
  });

  final String id;
  final String ownerId;
  final double latitude;
  final double longitude;

  /// From the service's `visibility`. Anything unrecognised reads as
  /// [FrameAudience.private], so a value this build does not know can never
  /// widen who sees a frame.
  final FrameAudience audience;

  /// How far the service measured the frame to be from the query point, or
  /// null when the response did not say (for example a user's own list).
  final double? distanceMeters;
  final String caption;
  final String? mediaId;
  final String? thumbnailUrl;
  final String? mediaUrl;
  final double? altitudeMeters;
  final double? headingDegrees;
  final String? mediaStatus;
  final String? moderationStatus;
  final DateTime? capturedAt;

  /// The id of the look the owner gave the frame (`frameStyle` from the
  /// service), or null when none was set. The service does not know the
  /// catalog, so it may be an id this build has never heard of; the frame
  /// renderer falls back to its default look for those.
  final String? frameStyle;

  /// Reads one entry of `/memories/nearby` (a minimap dot) or of `/feed` and
  /// `/users/{id}` (a full memory). Returns null for an entry that is not
  /// usable (no id, owner or position), so one bad row never hides the rest.
  static RemoteFrame? tryParse(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = _text(json['id']);
    final ownerId = _text(json['ownerId']);
    final position = json['position'];
    if (id == null || ownerId == null || position is! Map) {
      return null;
    }
    final latitude = _number(position['latitude']);
    final longitude = _number(position['longitude']);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return RemoteFrame(
      id: id,
      ownerId: ownerId,
      latitude: latitude,
      longitude: longitude,
      altitudeMeters: _number(position['altitudeMeters']),
      headingDegrees: _number(json['headingDegrees']) ??
          (json['anchor'] is Map
              ? _number((json['anchor'] as Map)['headingDegrees'])
              : null),
      // Dots have no visibility; the service only returns them when the
      // viewer may see them, so keep the safe reading until told otherwise.
      audience: FrameAudience.fromName(
        json['visibility'],
        FrameAudience.private,
      ),
      distanceMeters: _number(json['distanceMeters']),
      caption: _text(json['caption']) ?? '',
      mediaId: _text(json['mediaId']),
      thumbnailUrl: _text(json['thumbnailUrl']),
      mediaUrl: _text(json['mediaUrl']),
      mediaStatus: _text(json['mediaStatus']),
      moderationStatus: _text(json['moderationStatus']),
      capturedAt: _time(json['capturedAt']),
      frameStyle: _text(json['frameStyle'])?.trim(),
    );
  }

  /// Reads a list, dropping unusable entries.
  static List<RemoteFrame> parseList(Object? json) {
    if (json is! List) {
      return const <RemoteFrame>[];
    }
    return List.unmodifiable([
      for (final entry in json)
        if (tryParse(entry) case final frame?) frame,
    ]);
  }

  static String? _text(Object? value) {
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  static double? _number(Object? value) {
    return value is num && value.isFinite ? value.toDouble() : null;
  }

  static DateTime? _time(Object? value) {
    return value is String ? DateTime.tryParse(value) : null;
  }
}
