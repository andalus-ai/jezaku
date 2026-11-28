import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jezaku_ar/jezaku_ar.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/presentation/ar_capability_pills.dart';
import 'package:jejaku/features/ar_viewer/services/ar_diagnostics_presentation.dart';
import 'package:material_ui/material_ui.dart';

final _colors = ColorScheme.fromSeed(seedColor: Colors.teal);

JejakuARSessionPlan _plan(ARCapabilities engine, {bool preferDepth = false}) {
  return JejakuARCapabilities(engine: engine).planSession(
    preferDepth: preferDepth,
  );
}

List<ARCapabilityPill> _pills(
  AsyncValue<JejakuARSessionPlan> plan, {
  ARMemorySceneDiagnostics diagnostics = const ARMemorySceneDiagnostics(),
}) {
  return ARCapabilityPills.forPlan(plan, diagnostics, _colors);
}

AsyncValue<JejakuARSessionPlan> _data(ARCapabilities engine,
        {bool preferDepth = false}) =>
    AsyncData(_plan(engine, preferDepth: preferDepth));

const _local = ARCapabilities(
  isARSupported: true,
  supportsWorldTracking: true,
  supportsSnapshotCapture: true,
);

const _geo = ARCapabilities(
  isARSupported: true,
  supportsWorldTracking: true,
  supportsGeospatial: true,
  supportsSnapshotCapture: true,
  supportsRecordingEncode: true,
);

void main() {
  group('while the session is being checked', () {
    test('shows that both checks are running', () {
      final pills = _pills(const AsyncLoading());

      expect(pills.map((p) => p.label), ['AR check', 'Rec check']);
      expect(pills.every((p) => p.color == _colors.secondary), isTrue);
    });

    test('shows what works without native AR when the check failed', () {
      final pills = _pills(AsyncError(StateError('x'), StackTrace.empty));

      expect(pills.map((p) => p.label), ['Local AR', 'No rec']);
      expect(pills.first.color, _colors.primary);
      expect(pills.last.color, _colors.onSurfaceVariant);
    });
  });

  group('placement', () {
    test('a device with geospatial AR says so', () {
      final pill = _pills(_data(_geo)).first;

      expect(pill.label, 'Geo AR');
      expect(pill.icon, Icons.public);
      expect(pill.color, _colors.primary);
      expect(pill.tooltip, isNull);
    });

    test('world tracking without geospatial is local AR', () {
      final pill = _pills(_data(_local)).first;

      expect(pill.label, 'Local AR');
      expect(pill.icon, Icons.map_outlined);
      expect(pill.color, _colors.primary);
    });

    test('a device without AR says AR is off, in a muted colour', () {
      final pill = _pills(_data(const ARCapabilities.unsupported())).first;

      expect(pill.label, 'AR off');
      expect(pill.icon, Icons.portable_wifi_off);
      expect(pill.color, _colors.onSurfaceVariant);
    });

    test('placement the session cannot do right now is shown as paused', () {
      const readiness = ARSessionReadiness(
        level: ARSessionReadinessLevel.limited,
        label: 'Limited',
        detailLabel: 'Move the phone slowly.',
        canPlaceAnchors: false,
        canCaptureSnapshot: true,
        canRecord: true,
      );
      final diagnostics =
          const ARMemorySceneDiagnostics().copyWith(nativePlacementReadiness: readiness);

      final pill = _pills(_data(_geo), diagnostics: diagnostics).first;

      expect(pill.label, 'Place paused');
      expect(pill.icon, Icons.motion_photos_pause_outlined);
      expect(pill.tooltip, 'Move the phone slowly.');
      expect(
        pill.color,
        ARDiagnosticsPresentation.sessionHealthColor(diagnostics, _colors),
      );
    });

    test('a session that can place frames is not shown as paused', () {
      const readiness = ARSessionReadiness(
        level: ARSessionReadinessLevel.ready,
        label: 'AR ready',
        detailLabel: 'Fine.',
        canPlaceAnchors: true,
        canCaptureSnapshot: true,
        canRecord: true,
      );
      final diagnostics =
          const ARMemorySceneDiagnostics().copyWith(nativePlacementReadiness: readiness);

      expect(_pills(_data(_geo), diagnostics: diagnostics).first.label, 'Geo AR');
    });

    test('a device that cannot place frames is never "paused"', () {
      const readiness = ARSessionReadiness(
        level: ARSessionReadinessLevel.blocked,
        label: 'Blocked',
        detailLabel: 'No.',
        canPlaceAnchors: false,
        canCaptureSnapshot: false,
        canRecord: false,
      );
      final diagnostics =
          const ARMemorySceneDiagnostics().copyWith(nativePlacementReadiness: readiness);

      final pills = _pills(
        _data(const ARCapabilities.unsupported()),
        diagnostics: diagnostics,
      );

      expect(pills.first.label, 'AR off');
    });
  });

  group('recording', () {
    test('native encoding is "Screen rec" with its tooltip', () {
      final pill = _pills(_data(_geo))[1];

      expect(pill.label, 'Screen rec');
      expect(pill.tooltip, contains('Native MP4'));
      expect(pill.color, _colors.primary);
    });

    test('snapshots without native encoding are the Dart fallback', () {
      final pill = _pills(_data(_local))[1];

      expect(pill.label, 'Screen fallback');
      expect(pill.tooltip, contains('Dart fallback'));
      expect(pill.color, _colors.primary);
    });

    test('no snapshot capture means no recording, in a muted colour', () {
      final pill = _pills(_data(const ARCapabilities.unsupported()))[1];

      expect(pill.label, 'No rec');
      expect(pill.tooltip, isNull);
      expect(pill.color, _colors.onSurfaceVariant);
    });
  });

  group('limited features', () {
    test('the "AR limited" pill appears exactly when the plan was downgraded',
        () {
      for (final engine in [_geo, _local]) {
        final plan = _plan(engine);

        final pills = _pills(AsyncData(plan));

        expect(
          pills.any((p) => p.label == 'AR limited'),
          plan.hasNativeDowngrades,
        );
        expect(pills, hasLength(plan.hasNativeDowngrades ? 3 : 2));
      }
    });

    test('turned-off native features add an "AR limited" pill', () {
      final plan = _plan(_local, preferDepth: true);
      expect(plan.hasNativeDowngrades, isTrue,
          reason: 'depth was asked for on a device without it');

      final pills = _pills(AsyncData(plan));

      expect(pills, hasLength(3));
      expect(pills.last.label, 'AR limited');
      expect(pills.last.icon, Icons.tune);
      expect(pills.last.color, _colors.tertiary);
      expect(pills.last.tooltip, startsWith('Disabled native features: '));
    });
  });
}
