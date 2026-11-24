import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/frame_styles/models/frame_look.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/screens/memory_photo_screen.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/settings/models/app_settings.dart';
import 'package:jejaku/features/settings/screens/settings_screen.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

AnchorMemory _addFrame(
  ProviderContainer container, {
  String? ownerId,
  String frameLookId = 'classic',
  int? frameColorValue,
}) {
  return container.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
        caption: 'Cabinet in the hallway',
        radiusMeters: 30,
        isPrivate: false,
        ownerId: ownerId,
        frameLookId: frameLookId,
        frameColorValue: frameColorValue,
        capturedAt: DateTime(2026, 11, 20, 18, 7),
      );
}

AnchorMemory _current(ProviderContainer container, String id) {
  return container
      .read(nearbyAnchorsProvider)
      .firstWhere((memory) => memory.id == id);
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
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('frame style on a memory', () {
    test('a new frame defaults to the classic look with no colour', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final memory = _addFrame(container);

      expect(memory.frameLookId, defaultFrameLookId);
      expect(memory.frameColorValue, isNull);
    });

    test('updateFrameStyle changes the look and can clear the colour', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final memory = _addFrame(container, frameColorValue: 0xFFC0392B);
      final notifier = container.read(nearbyAnchorsProvider.notifier);

      notifier.updateFrameStyle(
        memoryId: memory.id,
        lookId: 'dark_gallery',
        colorValue: 0xFF2E6FD8,
      );
      expect(_current(container, memory.id).frameLookId, 'dark_gallery');
      expect(_current(container, memory.id).frameColorValue, 0xFF2E6FD8);

      notifier.updateFrameStyle(memoryId: memory.id, lookId: 'thin');
      expect(_current(container, memory.id).frameLookId, 'thin');
      expect(_current(container, memory.id).frameColorValue, isNull);
    });

    test('a restyle is cosmetic: it does not touch sync status or audience', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final memory = _addFrame(container);

      container.read(nearbyAnchorsProvider.notifier).updateFrameStyle(
            memoryId: memory.id,
            lookId: 'gold',
          );

      final after = _current(container, memory.id);
      expect(after.syncStatus, memory.syncStatus);
      expect(after.audience, memory.audience);
    });

    test('the look and colour survive a store round trip', () async {
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesAnchorMemoryStore(
        preferences: preferences,
      );
      final first = ProviderContainer(
        overrides: [anchorMemoryStoreProvider.overrideWithValue(store)],
      );
      addTearDown(first.dispose);
      final memory = _addFrame(
        first,
        frameLookId: 'oak',
        frameColorValue: 0xFF2E8B57,
      );

      final second = ProviderContainer(
        overrides: [anchorMemoryStoreProvider.overrideWithValue(store)],
      );
      addTearDown(second.dispose);
      final restored = _current(second, memory.id);

      expect(restored.frameLookId, 'oak');
      expect(restored.frameColorValue, 0xFF2E8B57);
    });

    test('the look reaches the AR scene metadata, and classic adds nothing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final plain = _addFrame(container);
      final styled = _addFrame(container, frameLookId: 'dark_gallery');

      final plainMetadata = plain.toJejakuGeoAnchor().metadata;
      final styledMetadata = styled.toJejakuGeoAnchor().metadata;

      expect(plainMetadata.containsKey('photoFramePreset'), isFalse);
      expect(styledMetadata['photoFramePreset'], 'darkGallery');
    });
  });

  group('default frame setting', () {
    test('is classic until changed, and is saved and restored as json', () {
      const base = AppSettings(
        nearbyNotifications: true,
        privateByDefault: false,
        highAccuracyMode: true,
        familyLocationAlerts: true,
        weeklyGuardianDigest: true,
        approvalReminders: true,
        cachedMediaMb: 0,
        sharePreciseLocation: true,
        commentsEnabledByDefault: true,
        profileDiscoverable: true,
        blockedAccounts: <String>[],
      );
      expect(base.defaultFrameLookId, defaultFrameLookId);
      expect(base.defaultFrameColorValue, isNull);

      final changed = base.copyWith(
        defaultFrameLookId: 'gold',
        defaultFrameColorValue: 0xFFC0392B,
      );
      final restored = AppSettings.fromJson(changed.toJson(), fallback: base);
      expect(restored.defaultFrameLookId, 'gold');
      expect(restored.defaultFrameColorValue, 0xFFC0392B);

      final cleared = changed.copyWith(defaultFrameColorValue: null);
      expect(cleared.defaultFrameColorValue, isNull);
      expect(cleared.defaultFrameLookId, 'gold');
    });

    test('older saved settings without the field keep the fallback', () {
      const fallback = AppSettings(
        nearbyNotifications: true,
        privateByDefault: false,
        highAccuracyMode: true,
        familyLocationAlerts: true,
        weeklyGuardianDigest: true,
        approvalReminders: true,
        cachedMediaMb: 0,
        sharePreciseLocation: true,
        commentsEnabledByDefault: true,
        profileDiscoverable: true,
        blockedAccounts: <String>[],
        defaultFrameLookId: 'thin',
      );
      final restored =
          AppSettings.fromJson({'privateByDefault': true}, fallback: fallback);
      expect(restored.defaultFrameLookId, 'thin');
    });

    testWidgets('Settings lets the user pick the default frame',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();

      final tile = find.byKey(const ValueKey('default_frame_tile'));
      await tester.scrollUntilVisible(
        tile,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // scrollUntilVisible stops as soon as the tile's edge shows; bring the
      // whole tile on screen so the tap lands on it.
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('frame_look_gold')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('frame_style_apply')));
      await tester.pumpAndSettle();

      final settings = container.read(appSettingsProvider);
      expect(settings.defaultFrameLookId, 'gold');
    });
  });

  group('change frame from the photo page', () {
    testWidgets('the author picks a look and a colour', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final memory = _addFrame(container);
      await _pumpPhoto(tester, container, memory.id);

      await tester
          .tap(find.byKey(const ValueKey('memory_photo_change_frame_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('frame_look_dark_gallery')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('frame_color_${0xFFD4AF37}')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('frame_style_apply')));
      await tester.pumpAndSettle();

      final after = _current(container, memory.id);
      expect(after.frameLookId, 'dark_gallery');
      expect(after.frameColorValue, 0xFFD4AF37);
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final memory = _addFrame(container, frameLookId: 'oak');
      await _pumpPhoto(tester, container, memory.id);

      await tester
          .tap(find.byKey(const ValueKey('memory_photo_change_frame_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('frame_look_thin')));
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(_current(container, memory.id).frameLookId, 'oak');
    });

    testWidgets("someone else's frame has no change-frame or details button",
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final memory = _addFrame(container, ownerId: 'someone-else');
      await _pumpPhoto(tester, container, memory.id);

      expect(
        find.byKey(const ValueKey('memory_photo_change_frame_button')),
        findsNothing,
      );
      // Details open the owner's local record, so they are owner-only too.
      expect(
        find.byKey(const ValueKey('memory_photo_details_button')),
        findsNothing,
      );
    });
  });
}
