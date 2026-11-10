import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

ARGeospatialStatus _tracking({
  double? horizontal = 1.5,
  double? heading = 2,
  double? vertical = 2,
  String earthState = 'ENABLED',
}) {
  return ARGeospatialStatus(
    isEnabled: true,
    isTracking: true,
    earthState: earthState,
    pose: ARGeospatialPose(
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 714,
      headingDegrees: 90,
      horizontalAccuracyMeters: horizontal,
      verticalAccuracyMeters: vertical,
      headingAccuracyDegrees: heading,
    ),
  );
}

void main() {
  const policy = JejakuPlacementPolicy();

  group('JejakuPlacementPolicy.assess', () {
    test('is precise when every accuracy is within the thresholds', () {
      final result = policy.assess(status: _tracking());

      expect(result.quality, JejakuPlacementMode.precise);
      expect(result.reason, JejakuPlacementReason.accurate);
      expect(result.isPrecise, isTrue);
      expect(result.detailLabel, contains('±1.5 m'));
    });

    test('thresholds are inclusive', () {
      final result = policy.assess(
        status: _tracking(horizontal: 3, heading: 5, vertical: 5),
      );

      expect(result.isPrecise, isTrue);
    });

    test('null or missing status is approximate', () {
      expect(
        policy.assess().reason,
        JejakuPlacementReason.geospatialUnavailable,
      );
      expect(
        policy.assess(status: const ARGeospatialStatus.unsupported()).quality,
        JejakuPlacementMode.approximate,
      );
    });

    test('geospatial mode off is approximate', () {
      final result = policy.assess(
        status: const ARGeospatialStatus(isEnabled: false),
      );

      expect(result.reason, JejakuPlacementReason.geospatialUnavailable);
    });

    test('enabled but not tracking reports localizing', () {
      final result = policy.assess(
        status: const ARGeospatialStatus(
          isEnabled: true,
          isTracking: false,
          earthState: 'ENABLED',
        ),
      );

      expect(result.quality, JejakuPlacementMode.approximate);
      expect(result.reason, JejakuPlacementReason.localizing);
    });

    test('tracking without a pose reports localizing', () {
      final result = policy.assess(
        status: const ARGeospatialStatus(isEnabled: true, isTracking: true),
      );

      expect(result.reason, JejakuPlacementReason.localizing);
    });

    test('authorization errors are reported separately from localizing', () {
      final fromEarth = policy.assess(
        status: const ARGeospatialStatus(
          isEnabled: true,
          earthState: 'ERROR_NOT_AUTHORIZED',
        ),
      );
      final fromVps = policy.assess(
        status: _tracking(),
        vps: ARVpsAvailability.errorNotAuthorized,
      );

      expect(fromEarth.reason, JejakuPlacementReason.notAuthorized);
      expect(fromVps.reason, JejakuPlacementReason.notAuthorized);
      expect(fromVps.isPrecise, isFalse);
    });

    test('quota exhaustion is reported', () {
      final fromEarth = policy.assess(
        status: const ARGeospatialStatus(
          isEnabled: true,
          earthState: 'ERROR_RESOURCE_EXHAUSTED',
        ),
      );
      final fromVps = policy.assess(
        status: _tracking(),
        vps: ARVpsAvailability.errorResourceExhausted,
      );

      expect(fromEarth.reason, JejakuPlacementReason.resourceExhausted);
      expect(fromVps.reason, JejakuPlacementReason.resourceExhausted);
    });

    test('missing horizontal or heading accuracy is not precise', () {
      expect(
        policy.assess(status: _tracking(horizontal: null)).reason,
        JejakuPlacementReason.accuracyUnknown,
      );
      expect(
        policy.assess(status: _tracking(heading: null)).reason,
        JejakuPlacementReason.accuracyUnknown,
      );
    });

    test('non-finite or negative accuracy is treated as unknown', () {
      expect(
        policy.assess(status: _tracking(horizontal: double.nan)).reason,
        JejakuPlacementReason.accuracyUnknown,
      );
      expect(
        policy.assess(status: _tracking(heading: -1)).reason,
        JejakuPlacementReason.accuracyUnknown,
      );
    });

    test('horizontal accuracy above the threshold is approximate', () {
      final result = policy.assess(status: _tracking(horizontal: 3.1));

      expect(result.reason, JejakuPlacementReason.horizontalAccuracyTooLow);
      expect(result.detailLabel, contains('3.1'));
    });

    test('heading accuracy above the threshold is approximate', () {
      final result = policy.assess(status: _tracking(heading: 5.1));

      expect(result.reason, JejakuPlacementReason.headingAccuracyTooLow);
    });

    test('vertical accuracy above the threshold is approximate', () {
      final result = policy.assess(status: _tracking(vertical: 5.1));

      expect(result.reason, JejakuPlacementReason.verticalAccuracyTooLow);
    });

    test('a missing vertical accuracy does not block precise placement', () {
      final result = policy.assess(status: _tracking(vertical: null));

      expect(result.isPrecise, isTrue);
    });

    test('VPS unavailable alone does not decide the result', () {
      final result = policy.assess(
        status: _tracking(),
        vps: ARVpsAvailability.unavailable,
      );

      // The accuracy estimates are authoritative: if ARCore reports a good
      // fix without VPS, the policy trusts the numbers.
      expect(result.isPrecise, isTrue);
    });

    test('custom thresholds are honoured', () {
      const strict = JejakuPlacementPolicy(
        maxHorizontalAccuracyMeters: 1,
        maxHeadingAccuracyDegrees: 1,
        maxVerticalAccuracyMeters: 1,
      );

      expect(
        strict.assess(status: _tracking()).reason,
        JejakuPlacementReason.horizontalAccuracyTooLow,
      );
    });
  });

  group('JejakuPlacementAssessment', () {
    test('initial assessment is approximate', () {
      const initial = JejakuPlacementAssessment.initial();

      expect(initial.isPrecise, isFalse);
      expect(initial.shortLabel, 'Approx.');
    });

    test('precise assessment has a short label', () {
      expect(policy.assess(status: _tracking()).shortLabel, 'Precise');
    });

    test('every reason has a non-empty explanation', () {
      final statuses = <ARGeospatialStatus?>[
        null,
        const ARGeospatialStatus(isEnabled: true, earthState: 'ENABLED'),
        const ARGeospatialStatus(
          isEnabled: true,
          earthState: 'ERROR_NOT_AUTHORIZED',
        ),
        const ARGeospatialStatus(
          isEnabled: true,
          earthState: 'ERROR_RESOURCE_EXHAUSTED',
        ),
        _tracking(),
        _tracking(horizontal: null),
        _tracking(horizontal: 10),
        _tracking(heading: 30),
        _tracking(vertical: 20),
      ];

      final reasons = <JejakuPlacementReason>{};
      for (final status in statuses) {
        final assessment = policy.assess(status: status);
        reasons.add(assessment.reason);
        expect(assessment.detailLabel, isNotEmpty);
      }

      expect(reasons, JejakuPlacementReason.values.toSet());
    });
  });
}
