import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/home/screens/memory_photo_screen.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';
import 'package:jejaku/features/remote_frames/services/remote_frame_mapper.dart';
import 'package:jejaku/features/remote_frames/states/viewer_anchors_provider.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets("someone else's frame opens on the photo page without owner tools",
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final remote = RemoteFrameMapper.toAnchorMemory(
      RemoteFrame(
        id: 'remote-1',
        ownerId: 'someone-else',
        latitude: -6.2,
        longitude: 106.8,
        audience: FrameAudience.public,
        distanceMeters: 12,
        caption: 'Mural by the station',
      ),
    );
    final container = ProviderContainer(
      overrides: [viewerAnchorsProvider.overrideWithValue([remote])],
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

    expect(find.text('Mural by the station'), findsWidgets);
    expect(
      find.byKey(const ValueKey('memory_photo_details_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('memory_photo_change_frame_button')),
      findsNothing,
    );
  });
}
