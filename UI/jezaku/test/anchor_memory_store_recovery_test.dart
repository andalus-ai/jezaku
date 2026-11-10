import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/services/sample_anchor_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferencesAnchorMemoryStore> _store(
  Map<String, Object> initial,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final preferences = await SharedPreferences.getInstance();
  return SharedPreferencesAnchorMemoryStore(
    preferences: preferences,
    key: 'test.memories',
  );
}

void main() {
  test('unreadable data is backed up instead of destroyed', () async {
    final store = await _store({'test.memories': '{not valid json'});

    expect(store.loadCapturedMemories(), isEmpty);
    await Future<void>.delayed(Duration.zero);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('test.memories'), isNull);
    expect(preferences.getString(store.corruptBackupKey), '{not valid json');
  });

  test('wrongly shaped data is also backed up', () async {
    final store = await _store({'test.memories': '{"memories": []}'});

    expect(store.loadCapturedMemories(), isEmpty);
    await Future<void>.delayed(Duration.zero);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(store.corruptBackupKey), '{"memories": []}');
  });

  test('valid data round trips and leaves no backup', () async {
    final store = await _store(const {});
    final memories = const SampleAnchorService().nearbyAnchors().take(2);

    store.saveCapturedMemories(memories.toList());
    await Future<void>.delayed(Duration.zero);

    final loaded = store.loadCapturedMemories();
    expect(loaded.map((memory) => memory.id),
        memories.map((memory) => memory.id));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(store.corruptBackupKey), isNull);
  });
}
