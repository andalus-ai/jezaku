import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/sync/services/anchor_media_upload_queue_store.dart';
import 'package:jejaku/features/sync/services/anchor_sync_delivery_log_store.dart';
import 'package:jejaku/features/trails/services/ar_trail_progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('upload queue store', () {
    test('unreadable data is backed up, not destroyed', () async {
      final preferences = await _prefs({'q': '{broken'});
      final store = SharedPreferencesAnchorMediaUploadQueueStore(
        preferences: preferences,
        key: 'q',
      );

      expect(store.loadUploadEntries(), isEmpty);
      await _flush();

      expect(preferences.getString('q'), isNull);
      expect(preferences.getString(store.corruptBackupKey), '{broken');
    });

    test('wrongly shaped data is backed up too', () async {
      final preferences = await _prefs({'q': '{"a": 1}'});
      final store = SharedPreferencesAnchorMediaUploadQueueStore(
        preferences: preferences,
        key: 'q',
      );

      expect(store.loadUploadEntries(), isEmpty);
      await _flush();

      expect(preferences.getString(store.corruptBackupKey), '{"a": 1}');
    });

    test('an empty queue leaves no backup', () async {
      final preferences = await _prefs(const {});
      final store = SharedPreferencesAnchorMediaUploadQueueStore(
        preferences: preferences,
        key: 'q',
      );

      expect(store.loadUploadEntries(), isEmpty);
      await _flush();

      expect(preferences.getString(store.corruptBackupKey), isNull);
    });
  });

  group('delivery log store', () {
    test('unreadable data is backed up, not destroyed', () async {
      final preferences = await _prefs({'log': 'not json'});
      final store = SharedPreferencesAnchorSyncDeliveryLogStore(
        preferences: preferences,
        key: 'log',
      );

      expect(store.loadEntries(), isEmpty);
      await _flush();

      expect(preferences.getString('log'), isNull);
      expect(preferences.getString(store.corruptBackupKey), 'not json');
    });
  });

  group('trail progress store', () {
    test('unreadable active progress is backed up', () async {
      final preferences = await _prefs({'active': '[1, 2'});
      final store = SharedPreferencesARTrailProgressStore(
        preferences: preferences,
        activeProgressKey: 'active',
      );

      expect(store.loadActiveProgress(), isNull);
      await _flush();

      expect(preferences.getString('active'), isNull);
      expect(preferences.getString('active.corrupt'), '[1, 2');
    });

    test('wrongly shaped history is backed up', () async {
      final preferences = await _prefs({'history': '{"x": 1}'});
      final store = SharedPreferencesARTrailProgressStore(
        preferences: preferences,
        completedHistoryKey: 'history',
      );

      expect(store.loadCompletedHistory(), isEmpty);
      await _flush();

      expect(preferences.getString('history.corrupt'), '{"x": 1}');
    });

    test('unreadable lifetime stats are backed up', () async {
      final preferences = await _prefs({'stats': 'oops'});
      final store = SharedPreferencesARTrailProgressStore(
        preferences: preferences,
        lifetimeStatsKey: 'stats',
      );

      store.loadLifetimeStats();
      await _flush();

      expect(preferences.getString('stats'), isNull);
      expect(preferences.getString('stats.corrupt'), 'oops');
    });
  });
}
