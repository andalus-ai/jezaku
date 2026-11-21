import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/screens/memory_photo_screen.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:jejaku/features/social/states/social_providers.dart';
import 'package:material_ui/material_ui.dart';

AnchorMemory _addFrame(
  ProviderContainer container, {
  bool allowComments = true,
  String caption = 'Cabinet in the hallway',
}) {
  return container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
        caption: caption,
        radiusMeters: 30,
        isPrivate: false,
        allowComments: allowComments,
        capturedAt: DateTime(2026, 11, 20, 18, 7),
      );
}

Future<void> _pumpPhoto(
  WidgetTester tester,
  ProviderContainer container,
  String memoryId,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MemoryPhotoScreen(memoryId: memoryId),
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the frame and an empty comment thread', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final memory = _addFrame(container);

    await _pumpPhoto(tester, container, memory.id);

    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Cabinet in the hallway'), findsWidgets);
    expect(
      find.byKey(const ValueKey('memory_photo_comments_empty')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('comment_field')), findsOneWidget);
  });

  testWidgets('a friend can post a comment that appears in the thread',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final memory = _addFrame(container);
    await _pumpPhoto(tester, container, memory.id);

    await tester.enterText(
      find.byKey(const ValueKey('comment_field')),
      '  Love this spot  ',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pumpAndSettle();

    expect(find.text('Love this spot'), findsOneWidget);
    expect(find.text('Comments (1)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('memory_photo_comments_empty')),
      findsNothing,
    );
    expect(
      container.read(postCommentsProvider(memory.id)).single.text,
      'Love this spot',
    );
  });

  testWidgets('comments turned off hides the composer', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final memory = _addFrame(container, allowComments: false);

    await _pumpPhoto(tester, container, memory.id);

    expect(
      find.byKey(const ValueKey('memory_photo_comments_off')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('comment_field')), findsNothing);
  });

  testWidgets('comments from blocked accounts are hidden', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final memory = _addFrame(container);
    container.read(socialCommentsProvider.notifier).addComment(
          postId: memory.id,
          text: 'Hidden remark',
        );
    container.read(appSettingsProvider.notifier).blockAccount('you');

    await _pumpPhoto(tester, container, memory.id);

    expect(find.text('Hidden remark'), findsNothing);
    expect(
      find.byKey(const ValueKey('memory_photo_comments_empty')),
      findsOneWidget,
    );
  });

  testWidgets('a missing frame explains itself', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _pumpPhoto(tester, container, 'no-such-frame');

    expect(find.text('This frame is no longer available.'), findsOneWidget);
  });

  testWidgets('back returns to the screen that opened the photo',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final memory = _addFrame(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.memoryPhoto,
                    arguments: memory.id,
                  ),
                  child: const Text('Open frame'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open frame'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryPhotoScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(MemoryPhotoScreen), findsNothing);
    expect(find.text('Open frame'), findsOneWidget);
  });
}
