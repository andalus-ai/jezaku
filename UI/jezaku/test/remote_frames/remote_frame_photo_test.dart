import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/home/screens/memory_photo_screen.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';
import 'package:jejaku/features/remote_frames/services/remote_frame_mapper.dart';
import 'package:jejaku/features/remote_frames/states/viewer_anchors_provider.dart';
import 'package:material_ui/material_ui.dart';

const _owner = 'someone-else';

Future<void> _openPhotoPage(
  WidgetTester tester, {
  required String viewerId,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final frame = RemoteFrameMapper.toAnchorMemory(
    RemoteFrame(
      id: 'remote-1',
      ownerId: _owner,
      latitude: -6.2,
      longitude: 106.8,
      audience: FrameAudience.public,
      distanceMeters: 12,
      caption: 'Mural by the station',
      moderationStatus: 'approved',
    ),
  );
  final container = ProviderContainer(
    overrides: [
      viewerAnchorsProvider.overrideWithValue([frame]),
      frameViewerContextProvider.overrideWithValue(
        FrameViewerContext.forUser(userId: viewerId),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: const MemoryPhotoScreen(memoryId: 'remote-1'),
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("someone else's frame opens on the photo page without owner tools",
      (tester) async {
    await _openPhotoPage(tester, viewerId: 'me');

    expect(find.text('Mural by the station'), findsWidgets);
    expect(
      find.byKey(const ValueKey('memory_photo_details_button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('memory_photo_change_frame_button')),
      findsNothing,
    );
  });

  testWidgets('the owner keeps the owner tools on the photo page',
      (tester) async {
    await _openPhotoPage(tester, viewerId: _owner);

    expect(
      find.byKey(const ValueKey('memory_photo_details_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('memory_photo_change_frame_button')),
      findsOneWidget,
    );
  });
}
