import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

void main() {
  group('AnchorMemoryGeoAnchor', () {
    test('preserves geographic placement and visibility metadata', () {
      const memory = AnchorMemory(
        id: 'memory-1',
        title: 'Old town',
        caption: 'A place to remember',
        distanceLabel: '12 m',
        capturedAgo: 'just now',
        locationLabel: 'Bandung',
        latitude: -6.9175,
        longitude: 107.6191,
        reactions: 0,
        captureMetadata: AnchorCaptureMetadata(
          altitudeMeters: 720,
          headingDegrees: 45,
          pitchDegrees: 2,
          rollDegrees: -1,
          gpsAccuracyMeters: 4,
          anchorType: 'geospatial',
          captureSource: 'device',
          correctionEastMeters: 1.5,
        ),
        isPrivate: true,
      );

      final anchor = memory.toJejakuGeoAnchor();

      expect(anchor.id, memory.id);
      expect(anchor.title, memory.title);
      expect(anchor.latitude, memory.latitude);
      expect(anchor.longitude, memory.longitude);
      expect(anchor.altitudeMeters, 720);
      expect(anchor.headingDegrees, 45);
      expect(anchor.pitchDegrees, 2);
      expect(anchor.rollDegrees, -1);
      expect(anchor.correctionEastMeters, 1.5);
      expect(anchor.isPrivate, isTrue);
      expect(anchor.metadata['gpsAccuracyMeters'], 4);
      expect(anchor.metadata['hasManualCorrection'], isTrue);
      expect(anchor.metadata['captureSource'], 'device');
    });

    test('does not attach photo texture bytes by default', () {
      final memory = AnchorMemory(
        id: 'photo-1',
        title: 'Photo',
        caption: '',
        distanceLabel: '3 m',
        capturedAgo: 'today',
        locationLabel: 'Bandung',
        latitude: -6.9,
        longitude: 107.6,
        reactions: 0,
        captureMetadata: const AnchorCaptureMetadata(
          altitudeMeters: 700,
          headingDegrees: 0,
          pitchDegrees: 0,
          rollDegrees: 0,
          gpsAccuracyMeters: 3,
          anchorType: 'geospatial',
          captureSource: 'camera',
        ),
        mediaAttachment: AnchorMediaAttachment(
          type: AnchorMediaType.cameraPhoto,
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      );

      final anchor = memory.toJejakuGeoAnchor();

      expect(anchor.metadata['photoFrame'], isTrue);
      expect(anchor.metadata.containsKey('photoTextureBytes'), isFalse);
    });
  });
}
