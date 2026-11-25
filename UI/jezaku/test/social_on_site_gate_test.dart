import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility.dart';
import 'package:jejaku/features/home/screens/memory_photo_screen.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';
import 'package:jejaku/features/remote_frames/services/remote_frame_mapper.dart';
import 'package:jejaku/features/remote_frames/states/viewer_anchors_provider.dart';
import 'package:jejaku/features/social/models/social_post.dart';
import 'package:jejaku/features/social/screens/comments_screen.dart';
import 'package:jejaku/features/social/screens/notifications_screen.dart';
import 'package:jejaku/features/social/widgets/comment_composer.dart';
import 'package:jejaku/features/social/widgets/social_post_card.dart';
import 'package:material_ui/material_ui.dart';

const _lat = -6.9175;
const _lng = 107.6191;

/// Sample posts and notifications link to this id.
const _frameId = 'anchor_courtyard';

class _FixedLocation extends ViewerLocationController {
  _FixedLocation(this.location);

  final ViewerLocation location;

  @override
  ViewerLocation build() => location;
}

ViewerLocation _metersNorthOfFrame(double meters) => ViewerLocation(
      latitude: _lat + meters / 111320,
      longitude: _lng,
      isLive: true,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required double viewerMetersAway,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final frame = RemoteFrameMapper.toAnchorMemory(
    RemoteFrame(
      id: _frameId,
      ownerId: 'amy',
      latitude: _lat,
      longitude: _lng,
      audience: FrameAudience.public,
      distanceMeters: 5,
      caption: 'Courtyard sketch',
      moderationStatus: 'approved',
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        frameRulesModeProvider.overrideWithValue(FrameRulesMode.strict),
        viewerAnchorsProvider.overrideWithValue([frame]),
        viewerLocationProvider.overrideWith(
          () => _FixedLocation(_metersNorthOfFrame(viewerMetersAway)),
        ),
      ],
      child: MaterialApp(
        home: home,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _lockedKey = ValueKey('locked_frame_card');

void main() {
  group('comments on a post that links someone else\'s frame', () {
    testWidgets('are locked away from the frame', (tester) async {
      await _pump(
        tester,
        const CommentsScreen(postId: 'post_0'),
        viewerMetersAway: 340,
      );

      expect(find.byKey(_lockedKey), findsOneWidget);
      expect(find.textContaining('340 m away'), findsOneWidget);
      expect(find.byType(CommentComposer), findsNothing);
    });

    testWidgets('open on site', (tester) async {
      await _pump(
        tester,
        const CommentsScreen(postId: 'post_0'),
        viewerMetersAway: 8,
      );

      expect(find.byKey(_lockedKey), findsNothing);
      expect(find.byType(CommentComposer), findsOneWidget);
    });

    testWidgets('a post without a frame is never locked', (tester) async {
      await _pump(
        tester,
        const CommentsScreen(postId: 'post_1'),
        viewerMetersAway: 5000,
      );

      expect(find.byKey(_lockedKey), findsNothing);
      expect(find.byType(CommentComposer), findsOneWidget);
    });
  });

  group('the photo page', () {
    testWidgets('locks when the viewer is not on site', (tester) async {
      await _pump(
        tester,
        const MemoryPhotoScreen(memoryId: _frameId),
        viewerMetersAway: 340,
      );

      expect(find.byKey(_lockedKey), findsOneWidget);
      expect(find.byType(CommentComposer), findsNothing);
      expect(find.text('Courtyard sketch'), findsNothing);
    });

    testWidgets('stays open while the viewer is at the edge of the radius',
        (tester) async {
      await _pump(
        tester,
        const MemoryPhotoScreen(memoryId: _frameId),
        viewerMetersAway: 23,
      );

      expect(find.byKey(_lockedKey), findsNothing);
      expect(find.text('Courtyard sketch'), findsWidgets);
    });
  });

  group('notifications', () {
    testWidgets('explain instead of opening a frame that is far away',
        (tester) async {
      await _pump(
        tester,
        const NotificationsScreen(),
        viewerMetersAway: 340,
      );
      const button = ValueKey('notification_open_ar_notification_0');

      expect(
        find.descendant(
          of: find.byKey(button),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(button));
      await tester.pump();

      expect(
        find.textContaining('Frames open only on site'),
        findsOneWidget,
      );
      expect(find.text('Focused anchor'), findsNothing);
    });

    testWidgets('show the AR affordance on site', (tester) async {
      await _pump(
        tester,
        const NotificationsScreen(),
        viewerMetersAway: 8,
      );
      const button = ValueKey('notification_open_ar_notification_0');

      expect(
        find.descendant(
          of: find.byKey(button),
          matching: find.byIcon(Icons.view_in_ar),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(button),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsNothing,
      );
    });
  });

  group('SocialPostCard', () {
    final post = SocialPost(
      id: 'p',
      username: 'maya',
      caption: 'A view',
      location: 'Campus Walk',
      likes: 1,
      commentCount: 0,
      timestamp: DateTime(2026, 11, 24),
      hasArAnchor: true,
      linkedMemoryId: _frameId,
    );

    Future<void> pumpCard(WidgetTester tester, FrameAccess? access) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SocialPostCard(post: post, frameAccess: access),
            ),
          ),
        ),
      );
    }

    testWidgets('shows a lock and the distance when locked', (tester) async {
      await pumpCard(tester, const FrameAccess.locked(distanceMeters: 340));

      expect(find.text('Locked · 340 m'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      expect(find.byTooltip('Go to the frame to open it'), findsOneWidget);
      expect(find.byTooltip('Open AR anchor'), findsNothing);
    });

    testWidgets('says unavailable when the frame may not be seen',
        (tester) async {
      await pumpCard(tester, const FrameAccess.unavailable());

      expect(find.text('Unavailable'), findsOneWidget);
    });

    testWidgets('is unchanged when open or when there is no access info',
        (tester) async {
      for (final access in <FrameAccess?>[const FrameAccess.open(), null]) {
        await pumpCard(tester, access);

        expect(find.text('AR'), findsOneWidget);
        expect(find.byTooltip('Open AR anchor'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsNothing);
      }
    });
  });
}
