import 'dart:convert';

import 'package:flutter/material.dart' as m;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/my_frames/models/my_frames_filter.dart';
import 'package:jejaku/features/publish/widgets/frame_audience_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

AnchorMemory _memory({
  bool isPrivate = false,
  FrameAudience? audience,
  String? ownerId,
}) {
  return AnchorMemory(
    id: 'm1',
    title: 'Frame',
    caption: '',
    distanceLabel: '',
    capturedAgo: 'Today',
    locationLabel: '',
    latitude: -6.9,
    longitude: 107.6,
    reactions: 0,
    isPrivate: isPrivate,
    audience: audience,
    ownerId: ownerId,
    captureMetadata: const AnchorCaptureMetadata(
      altitudeMeters: 0,
      headingDegrees: 0,
      pitchDegrees: 0,
      rollDegrees: 0,
      gpsAccuracyMeters: 3,
      anchorType: 'Geo anchor',
      captureSource: 'GPS',
    ),
  );
}

FrameVisibilityDecision _audienceDecision(
  AnchorMemory memory,
  FrameViewerContext viewer,
) {
  return const FrameAudienceRule().evaluate(
    FrameVisibilityCandidate(memory: memory, horizontalDistanceMeters: 1),
    viewer,
  );
}

void main() {
  group('AnchorMemory audience', () {
    test('defaults to public and isPrivate is shorthand for private', () {
      expect(_memory().audience, FrameAudience.public);
      expect(_memory(isPrivate: true).audience, FrameAudience.private);
      expect(_memory(isPrivate: true).isPrivate, isTrue);
      expect(_memory(audience: FrameAudience.friends).isPrivate, isFalse);
    });

    test('an explicit audience wins over the shorthand', () {
      final memory = _memory(isPrivate: true, audience: FrameAudience.friends);
      expect(memory.audience, FrameAudience.friends);
    });

    test('copyWith changes the audience either way', () {
      final friends = _memory().copyWith(audience: FrameAudience.friends);
      expect(friends.audience, FrameAudience.friends);
      expect(friends.copyWith(isPrivate: true).audience, FrameAudience.private);
      expect(friends.copyWith(isPrivate: false).audience, FrameAudience.public);
      expect(friends.copyWith(caption: 'x').audience, FrameAudience.friends);
    });

    test('wire names match the backend visibility values', () {
      expect(
        [for (final a in FrameAudience.values) a.wireName],
        ['private', 'friends', 'public'],
      );
      expect(
        FrameAudience.fromName('friends', FrameAudience.public),
        FrameAudience.friends,
      );
      expect(
        FrameAudience.fromName('nonsense', FrameAudience.private),
        FrameAudience.private,
      );
    });
  });

  group('storage', () {
    const key = 'jejaku.captured_anchor_memories';

    Future<SharedPreferences> preferences() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      return SharedPreferences.getInstance();
    }

    test('audience and owner survive a save and load', () async {
      final prefs = await preferences();
      final store = SharedPreferencesAnchorMemoryStore(preferences: prefs);

      store.saveCapturedMemories([
        _memory(audience: FrameAudience.friends, ownerId: 'user_1'),
      ]);
      final loaded = store.loadCapturedMemories().single;

      expect(loaded.audience, FrameAudience.friends);
      expect(loaded.ownerId, 'user_1');
    });

    test('older saves with only isPrivate still load', () async {
      final prefs = await preferences();
      final store = SharedPreferencesAnchorMemoryStore(preferences: prefs);
      store.saveCapturedMemories([_memory(isPrivate: true)]);
      final saved = (jsonDecode(prefs.getString(key)!) as List)
          .cast<Map<String, Object?>>();
      for (final entry in saved) {
        entry
          ..remove('audience')
          ..remove('ownerId');
      }
      await prefs.setString(key, jsonEncode(saved));

      expect(store.loadCapturedMemories().single.audience,
          FrameAudience.private);

      for (final entry in saved) {
        entry['isPrivate'] = false;
      }
      await prefs.setString(key, jsonEncode(saved));

      expect(store.loadCapturedMemories().single.audience,
          FrameAudience.public);
    });
  });

  group('audience rule with a real viewer', () {
    final viewer = FrameViewerContext.forUser(
      userId: 'me',
      friendIds: {'pal'},
    );

    test('frames without an author id are the viewer\'s own', () {
      final secret = _memory(audience: FrameAudience.private);
      expect(_audienceDecision(secret, viewer).isVisible, isTrue);
    });

    test('friends-only frames show to the author\'s friends only', () {
      final byFriend =
          _memory(audience: FrameAudience.friends, ownerId: 'pal');
      final byStranger =
          _memory(audience: FrameAudience.friends, ownerId: 'stranger');

      expect(_audienceDecision(byFriend, viewer).isVisible, isTrue);
      expect(_audienceDecision(byStranger, viewer).isVisible, isFalse);
    });

    test('others\' private frames stay hidden, public ones show', () {
      final secret =
          _memory(audience: FrameAudience.private, ownerId: 'pal');
      final open = _memory(audience: FrameAudience.public, ownerId: 'stranger');

      expect(_audienceDecision(secret, viewer).isVisible, isFalse);
      expect(_audienceDecision(open, viewer).isVisible, isTrue);
    });

    test('my own frames show whatever the audience', () {
      final mine = _memory(audience: FrameAudience.private, ownerId: 'me');
      expect(_audienceDecision(mine, viewer).isVisible, isTrue);
    });

    test('demo rules let a stranger\'s friends-only frame through', () {
      final demo = FrameViewerContext.everyoneIsAFriend(viewer);
      final byStranger =
          _memory(audience: FrameAudience.friends, ownerId: 'stranger');

      expect(_audienceDecision(byStranger, demo).isVisible, isTrue);
    });
  });

  group('viewer context provider', () {
    test('strict uses the real graph, demo treats everyone as a friend', () {
      final byStranger =
          _memory(audience: FrameAudience.friends, ownerId: 'stranger');

      final strict = ProviderContainer(
        overrides: [
          frameRulesModeProvider.overrideWithValue(FrameRulesMode.strict),
          currentUserIdProvider.overrideWithValue('me'),
        ],
      );
      addTearDown(strict.dispose);
      final demo = ProviderContainer(
        overrides: [
          frameRulesModeProvider.overrideWithValue(FrameRulesMode.demo),
          currentUserIdProvider.overrideWithValue('me'),
        ],
      );
      addTearDown(demo.dispose);

      expect(
        _audienceDecision(byStranger, strict.read(frameViewerContextProvider))
            .isVisible,
        isFalse,
      );
      expect(
        _audienceDecision(byStranger, demo.read(frameViewerContextProvider))
            .isVisible,
        isTrue,
      );
    });
  });

  group('my frames', () {
    test('the Friends filter matches friends-only frames', () {
      expect(
        MyFramesFilter.friends.matches(_memory(audience: FrameAudience.friends)),
        isTrue,
      );
      expect(MyFramesFilter.friends.matches(_memory()), isFalse);
      expect(MyFramesFilter.private.matches(_memory(isPrivate: true)), isTrue);
    });
  });

  group('FrameAudienceSelector', () {
    testWidgets('shows all three choices and reports the pick', (tester) async {
      FrameAudience? picked;
      await tester.pumpWidget(
        m.MaterialApp(
          home: m.Scaffold(
            body: FrameAudienceSelector(
              selected: FrameAudience.public,
              onChanged: (value) => picked = value,
            ),
          ),
        ),
      );

      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Only me'), findsOneWidget);
      expect(
        find.text(FrameAudienceSelector.description(FrameAudience.public)),
        findsOneWidget,
      );

      await tester.tap(find.text('Friends'));
      await tester.pump();

      expect(picked, FrameAudience.friends);
    });
  });
}
