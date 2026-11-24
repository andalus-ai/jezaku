import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/hud/ar_hud_state.dart';
import 'package:jejaku/features/ar_viewer/hud/ar_hud_store.dart';
import 'package:jejaku/features/ar_viewer/screens/ar_viewer_screen.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capability_providers.dart';
import 'package:jezaku_ar/jezaku_ar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('ARHudState json', () {
    test('round-trips the preset and the enabled panels', () {
      final state = const ARHudState()
          .withPanel(ARHudPanel.radar, enabled: false)
          .withPanel(ARHudPanel.recording, enabled: true);

      final restored = ARHudState.fromJson(state.toJson());

      expect(restored, state);
      expect(restored.preset, ARHudPreset.manual);
    });

    test('a minimal preset round-trips as minimal', () {
      final state = ARHudState.fromPreset(ARHudPreset.minimal);

      expect(ARHudState.fromJson(state.toJson()), state);
    });

    test('Hide UI is not remembered: the HUD comes back visible', () {
      final hidden = const ARHudState().toggledMaster();

      expect(hidden.masterVisible, isFalse);
      expect(ARHudState.fromJson(hidden.toJson()).masterVisible, isTrue);
    });

    test('unknown panel names are ignored (an older or newer build)', () {
      final restored = ARHudState.fromJson(<String, Object?>{
        'preset': 'manual',
        'panels': <Object?>['radar', 'hologram', 42],
      });

      expect(restored.enabled, {ARHudPanel.radar});
    });

    test('unreadable values fall back to the default view', () {
      const fallback = ARHudState();
      expect(ARHudState.fromJson(null), fallback);
      expect(ARHudState.fromJson('nope'), fallback);
      expect(ARHudState.fromJson(<String, Object?>{'preset': 'x'}), fallback);
      expect(
        ARHudState.fromJson(
          <String, Object?>{'preset': 'minimal', 'panels': 'radar'},
        ),
        fallback,
      );
    });
  });

  group('ARHudStore', () {
    test('nothing saved means the default view', () async {
      final store = SharedPreferencesARHudStore(
        preferences: await SharedPreferences.getInstance(),
      );

      expect(store.load(), const ARHudState());
    });

    test('a saved layout is restored by a new store on the same prefs',
        () async {
      final preferences = await SharedPreferences.getInstance();
      final state = const ARHudState().withPanel(
        ARHudPanel.infoDashboard,
        enabled: false,
      );

      SharedPreferencesARHudStore(preferences: preferences).save(state);

      expect(
        SharedPreferencesARHudStore(preferences: preferences).load(),
        state,
      );
    });

    test('corrupt saved text falls back instead of throwing', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'jejaku.ar_hud': '{not json'},
      );
      final store = SharedPreferencesARHudStore(
        preferences: await SharedPreferences.getInstance(),
      );

      expect(store.load(), const ARHudState());
    });

    test('the in-memory store also forgets Hide UI', () {
      final store = InMemoryARHudStore()
        ..save(const ARHudState().toggledMaster());

      expect(store.load().masterVisible, isTrue);
    });
  });

  testWidgets('the AR viewer reopens with the HUD layout the viewer chose',
      (tester) async {
    final store = InMemoryARHudStore();
    Future<void> openViewer() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            arHudStoreProvider.overrideWithValue(store),
            arViewerCapabilitiesProvider.overrideWith((ref) async {
              return const JejakuARCapabilities(
                engine: ARCapabilities.unsupported(),
              );
            }),
          ],
          child: const MaterialApp(home: ARViewerScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    await openViewer();
    expect(find.byKey(const ValueKey('ar_anchor_radar')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ar_hud_settings_button')));
    await tester.pumpAndSettle();
    final radarSwitch = find.byKey(const ValueKey('ar_hud_radar_switch'));
    await tester.ensureVisible(radarSwitch);
    await tester.pumpAndSettle();
    await tester.tap(radarSwitch);
    await tester.pumpAndSettle();
    expect(store.load().isEnabled(ARHudPanel.radar), isFalse);

    // Leave the viewer, then open it again with the same store.
    await tester.pumpWidget(const SizedBox.shrink());
    await openViewer();

    expect(find.byKey(const ValueKey('ar_anchor_radar')), findsNothing);
    expect(
      find.byKey(const ValueKey('ar_hud_settings_button')),
      findsOneWidget,
    );
  });
}
