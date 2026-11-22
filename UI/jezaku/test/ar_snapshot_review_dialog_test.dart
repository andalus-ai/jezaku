import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_snapshot_review_dialog.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

const _pose = AnchorLocalPose(
  x: 0,
  y: 1,
  z: -1.5,
  qx: 0,
  qy: 0,
  qz: 0,
  qw: 1,
  planeId: 'plane_1',
  distanceMeters: 1.5,
);

void main() {
  group('arSnapshotPlacementLabel', () {
    test('explains when no placement is available', () {
      expect(
        arSnapshotPlacementLabel(null),
        'Placement unavailable — the photo can still be published.',
      );
    });

    test('describes surface and floating placements', () {
      expect(
        arSnapshotPlacementLabel(_pose),
        'Near a detected vertical surface • about 1.5 m away',
      );
      expect(
        arSnapshotPlacementLabel(
          const AnchorLocalPose(
            x: 0,
            y: 0,
            z: 0,
            qx: 0,
            qy: 0,
            qz: 0,
            qw: 1,
          ),
        ),
        'Floating in space • nearby ahead',
      );
    });
  });

  Future<void> open(
    WidgetTester tester, {
    required AnchorLocalPose? placement,
    required void Function(ARSnapshotReviewResult?) onResult,
    ValueChanged<AnchorLocalPose?>? onPlacementChanged,
    bool needsCalibration = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              onResult(
                await showARSnapshotReviewDialog(
                  context: context,
                  bytes: Uint8List(0),
                  placement: placement,
                  onPlacementChanged: onPlacementChanged ?? (_) {},
                  cameraPosition: const ARVector3(0, 1, 0),
                  needsCalibration: needsCalibration,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('each action resolves to its own result', (tester) async {
    ARSnapshotReviewResult? result;
    await open(tester, placement: null, onResult: (value) => result = value);
    expect(
      find.byKey(const ValueKey('ar_snapshot_confirmation_dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('ar_frame_review_distance_slider')),
        findsNothing);
    expect(find.text('Publish now'), findsOneWidget);
    expect(find.text('Review & publish'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ar_snapshot_calibration_note')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('ar_snapshot_use_button')));
    await tester.pumpAndSettle();
    expect(result, ARSnapshotReviewResult.review);

    await open(tester, placement: null, onResult: (value) => result = value);
    await tester.tap(
      find.byKey(const ValueKey('ar_snapshot_publish_now_button')),
    );
    await tester.pumpAndSettle();
    expect(result, ARSnapshotReviewResult.publishNow);

    await open(tester, placement: null, onResult: (value) => result = value);
    await tester.tap(find.byKey(const ValueKey('ar_snapshot_retake_button')));
    await tester.pumpAndSettle();
    expect(result, ARSnapshotReviewResult.retake);
  });

  testWidgets('rough GPS relabels the action and explains the drift risk',
      (tester) async {
    ARSnapshotReviewResult? result;
    await open(
      tester,
      placement: null,
      needsCalibration: true,
      onResult: (value) => result = value,
    );

    expect(find.text('Publish anyway'), findsOneWidget);
    expect(find.text('Publish now'), findsNothing);
    expect(
      find.byKey(const ValueKey('ar_snapshot_calibration_note')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('ar_snapshot_publish_now_button')),
    );
    await tester.pumpAndSettle();
    expect(result, ARSnapshotReviewResult.publishNow);
  });

  testWidgets('moving a slider reports a free-space pose', (tester) async {
    AnchorLocalPose? reported;
    await open(
      tester,
      placement: _pose,
      onResult: (_) {},
      onPlacementChanged: (pose) => reported = pose,
    );
    expect(find.text('Near a detected vertical surface • about 1.5 m away'),
        findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('ar_frame_review_distance_slider')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    expect(reported, isNotNull);
    expect(reported!.planeId, isNull);
    expect(reported!.distanceMeters, greaterThan(1.5));
    expect(find.textContaining('Floating in space'), findsOneWidget);
  });
}
