import 'dart:typed_data';

/// The photo of a frame, ready to upload.
class FramePhoto {
  const FramePhoto({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;

  /// One of the types the media service accepts, such as `image/jpeg`.
  final String contentType;
}

/// What the media service says about an uploaded photo.
enum MediaReview {
  /// Cleared: a public frame may use it.
  approved,

  /// Not reviewed yet.
  pending,

  /// Refused: the frame cannot be published with this photo.
  rejected,
}

/// Everything the memory service needs to create one frame, taken from the
/// local frame at the moment it is sent.
class FramePublishJob {
  const FramePublishJob({
    required this.memoryId,
    required this.ownerId,
    required this.visibility,
    required this.anchorType,
    required this.latitude,
    required this.longitude,
    required this.frameStyle,
    required this.capturedAt,
    this.photo,
    this.caption = '',
    this.altitudeMeters,
    this.headingDegrees,
    this.pitchDegrees,
    this.rollDegrees,
    this.gpsAccuracyMeters,
  });

  /// The frame's id on this device.
  final String memoryId;

  /// The signed-in user who publishes it.
  final String ownerId;

  /// `private`, `friends` or `public`.
  final String visibility;

  /// `geo`, `visual` or `hybrid`.
  final String anchorType;

  final double latitude;
  final double longitude;
  final String frameStyle;
  final DateTime capturedAt;

  /// The photo to upload, or null for a frame whose media cannot be uploaded
  /// yet (a recording or a 3D object).
  final FramePhoto? photo;

  final String caption;
  final double? altitudeMeters;
  final double? headingDegrees;
  final double? pitchDegrees;
  final double? rollDegrees;
  final double? gpsAccuracyMeters;

  bool get isPublic => visibility == 'public';
}

/// The calls the outbox makes to the server. Implementations throw
/// `ApiFailure`; tests use a fake.
abstract interface class FramePublisher {
  /// Uploads [photo] for [ownerId] and returns its media id.
  Future<String> uploadPhoto(FramePhoto photo, {required String ownerId});

  Future<MediaReview> reviewOf(String mediaId);

  /// Creates the frame from [job] using the uploaded [mediaId] and returns the
  /// frame's id on the server.
  Future<String> createFrame(FramePublishJob job, {required String mediaId});
}

/// Finds the data to send for a frame that is waiting in the outbox.
abstract interface class FramePublishJobSource {
  /// The job for [memoryId] as [ownerId], or null when the frame no longer
  /// exists on this device (it was deleted while waiting).
  FramePublishJob? jobFor(String memoryId, {required String ownerId});
}
