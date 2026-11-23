import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/my_frames/models/my_frames_filter.dart';
import 'package:jejaku/features/my_frames/screens/my_frames_screen.dart';
import 'package:jejaku/features/my_frames/states/my_frames_providers.dart';
import 'package:material_ui/material_ui.dart';

AnchorMemory _frame(
  String id, {
  DateTime? capturedAt,
  bool isPrivate = false,
  bool hasArExperience = true,
  double gpsAccuracyMeters = 3,
  AnchorMediaType? mediaType,
}) {
  return AnchorMemory(
    id: id,
    title: 'Frame $id',
    caption: '',
    distanceLabel: '',
    capturedAgo: 'Today',
    locationLabel: 'Here',
    latitude: -6.9,
    longitude: 107.6,
    reactions: 0,
    capturedAt: capturedAt,
    isPrivate: isPrivate,
    hasArExperience: hasArExperience,
    mediaAttachment:
        mediaType == null ? null : AnchorMediaAttachment(type: mediaType),
    captureMetadata: AnchorCaptureMetadata(
      altitudeMeters: 0,
      headingDegrees: 0,
      pitchDegrees: 0,
      rollDegrees: 0,
      gpsAccuracyMeters: gpsAccuracyMeters,
      anchorType: 'Geo anchor',
      captureSource: 'GPS',
    ),
  );
}

void main() {
  group('MyFramesFilter', () {
    final ar = _frame('ar');
    final photoOnly = _frame('photo', hasArExperience: false);
    final video = _frame('video', mediaType: AnchorMediaType.arRecording);
    final secret = _frame('secret', isPrivate: true);
    final drifting = _frame('drift', gpsAccuracyMeters: 20);

    test('all keeps every frame', () {
      for (final frame in [ar, photoOnly, video, secret, drifting]) {
        expect(MyFramesFilter.all.matches(frame), isTrue);
      }
    });

    test('each filter matches only its own kind of frame', () {
      expect(MyFramesFilter.ar.matches(ar), isTrue);
      expect(MyFramesFilter.ar.matches(photoOnly), isFalse);
      expect(MyFramesFilter.videos.matches(video), isTrue);
      expect(MyFramesFilter.videos.matches(ar), isFalse);
      expect(MyFramesFilter.private.matches(secret), isTrue);
      expect(MyFramesFilter.private.matches(ar), isFalse);
      expect(MyFramesFilter.needsCalibration.matches(drifting), isTrue);
      expect(MyFramesFilter.needsCalibration.matches(ar), isFalse);
    });
  });

  group('sortFramesNewestFirst', () {
    test('orders by capture time, newest first, undated last, stable', () {
      final old = _frame('old', capturedAt: DateTime(2026, 1, 1));
      final fresh = _frame('fresh', capturedAt: DateTime(2026, 11, 1));
      final undatedA = _frame('undatedA');
      final undatedB = _frame('undatedB');

      final sorted = sortFramesNewestFirst([undatedA, old, undatedB, fresh]);

      expect(
        sorted.map((frame) => frame.id),
        ['fresh', 'old', 'undatedA', 'undatedB'],
      );
    });

    test('does not mutate its input', () {
      final input = [
        _frame('a', capturedAt: DateTime(2026, 1, 1)),
        _frame('b', capturedAt: DateTime(2026, 2, 1)),
      ];
      sortFramesNewestFirst(input);
      expect(input.first.id, 'a');
    });
  });

  group('MyFramesScreen', () {
    Future<List<String>> pumpScreen(
      WidgetTester tester,
      List<AnchorMemory> frames,
    ) async {
      final pushed = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [ownFramesProvider.overrideWithValue(frames)],
          child: MaterialApp(
            home: const MyFramesScreen(),
            onGenerateRoute: (settings) {
              pushed.add('${settings.name}:${settings.arguments}');
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('pushed')),
              );
            },
          ),
        ),
      );
      await tester.pump();
      return pushed;
    }

    testWidgets('shows a tile per frame and the count', (tester) async {
      await pumpScreen(tester, [_frame('a'), _frame('b'), _frame('c')]);

      expect(find.text('3 frames'), findsOneWidget);
      expect(find.byKey(const ValueKey('my_frame_tile_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('my_frame_tile_c')), findsOneWidget);
      expect(find.textContaining('Friends see a frame only at the place'),
          findsOneWidget);
    });

    testWidgets('a filter narrows the grid and can be reset', (tester) async {
      await pumpScreen(tester, [_frame('a'), _frame('secret', isPrivate: true)]);

      await tester.tap(find.byKey(const ValueKey('my_frames_filter_private')));
      await tester.pump();

      expect(find.byKey(const ValueKey('my_frame_tile_secret')), findsOneWidget);
      expect(find.byKey(const ValueKey('my_frame_tile_a')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('my_frames_filter_videos')));
      await tester.pump();

      expect(find.text('Nothing matches this filter'), findsOneWidget);
      await tester.tap(find.text('Show all'));
      await tester.pump();

      expect(find.byKey(const ValueKey('my_frame_tile_a')), findsOneWidget);
    });

    testWidgets('tapping a tile opens that frame', (tester) async {
      final pushed = await pumpScreen(tester, [_frame('a'), _frame('b')]);

      await tester.tap(find.byKey(const ValueKey('my_frame_tile_b')));
      await tester.pumpAndSettle();

      expect(pushed.last, '/memory-details:b');
    });

    testWidgets('invites the first capture when there are no frames',
        (tester) async {
      final pushed = await pumpScreen(tester, const []);

      expect(find.text('No memories yet'), findsOneWidget);
      await tester.tap(find.text('Capture a memory'));
      await tester.pumpAndSettle();

      expect(pushed.last, startsWith('/camera'));
    });

    testWidgets('tiles describe themselves to screen readers', (tester) async {
      await pumpScreen(tester, [_frame('secret', isPrivate: true)]);

      expect(
        find.bySemanticsLabel(RegExp('Frame secret, Private')),
        findsOneWidget,
      );
    });
  });
}
