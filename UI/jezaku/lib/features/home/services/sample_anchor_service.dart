import 'package:jejaku/features/home/models/anchor_memory.dart';

class SampleAnchorService {
  const SampleAnchorService();

  List<AnchorMemory> nearbyAnchors() {
    return const [
      AnchorMemory(
        id: 'anchor_courtyard',
        title: 'Courtyard sketch',
        caption: 'A layered AR note pinned near the east gate.',
        distanceLabel: '12.5 m',
        capturedAgo: '2 hours ago',
        locationLabel: '-6.9175, 107.6191',
        latitude: -6.9175,
        longitude: 107.6191,
        reactions: 42,
        captureMetadata: AnchorCaptureMetadata(
          altitudeMeters: 714.2,
          headingDegrees: 245,
          pitchDegrees: -2.1,
          rollDegrees: 0.4,
          gpsAccuracyMeters: 3.2,
          anchorType: 'Hybrid geo/orientation',
          captureSource: 'GPS + compass + gyro',
        ),
      ),
      AnchorMemory(
        id: 'anchor_rooftop',
        title: 'Rooftop sunset',
        caption: 'Best seen from the stair landing at golden hour.',
        distanceLabel: '31 m',
        capturedAgo: 'Yesterday',
        locationLabel: '-6.9180, 107.6205',
        latitude: -6.9180,
        longitude: 107.6205,
        reactions: 96,
        captureMetadata: AnchorCaptureMetadata(
          altitudeMeters: 721.8,
          headingDegrees: 263,
          pitchDegrees: -4.4,
          rollDegrees: 1.1,
          gpsAccuracyMeters: 2.6,
          anchorType: 'Geo anchor',
          captureSource: 'GPS + barometer + gyro',
        ),
        mediaAttachment: AnchorMediaAttachment(
          type: AnchorMediaType.cameraPhoto,
        ),
      ),
      AnchorMemory(
        id: 'anchor_private',
        title: 'Family checkpoint',
        caption: 'Private safety marker shared with guardians.',
        distanceLabel: '54 m',
        capturedAgo: '3 days ago',
        locationLabel: '-6.9162, 107.6179',
        latitude: -6.9162,
        longitude: 107.6179,
        reactions: 8,
        captureMetadata: AnchorCaptureMetadata(
          altitudeMeters: 709.5,
          headingDegrees: 91,
          pitchDegrees: -1.2,
          rollDegrees: -0.8,
          gpsAccuracyMeters: 6.8,
          anchorType: 'Private geo anchor',
          captureSource: 'GPS + compass',
        ),
        isPrivate: true,
      ),
      AnchorMemory(
        id: 'anchor_mural',
        title: 'Hidden mural frame',
        caption: 'A saved frame aligned to the wall artwork.',
        distanceLabel: '88 m',
        capturedAgo: '1 week ago',
        locationLabel: '-6.9194, 107.6187',
        latitude: -6.9194,
        longitude: 107.6187,
        reactions: 128,
        captureMetadata: AnchorCaptureMetadata(
          altitudeMeters: 717.1,
          headingDegrees: 184,
          pitchDegrees: -3.8,
          rollDegrees: 0.2,
          gpsAccuracyMeters: 4.5,
          anchorType: 'Visual-assisted geo',
          captureSource: 'GPS + gyro + visual alignment',
        ),
        mediaAttachment: AnchorMediaAttachment(
          type: AnchorMediaType.arSnapshot,
        ),
      ),
    ];
  }
}
