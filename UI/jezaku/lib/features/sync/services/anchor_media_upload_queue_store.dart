import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _anchorMediaUploadQueueKey = 'jejaku.anchor_media_upload_queue';

final anchorMediaUploadQueueStoreProvider =
    Provider<AnchorMediaUploadQueueStore>((ref) {
  return InMemoryAnchorMediaUploadQueueStore();
});

persistentAnchorMediaUploadQueueStoreOverride({
  required SharedPreferences preferences,
}) {
  return anchorMediaUploadQueueStoreProvider.overrideWith((ref) {
    return SharedPreferencesAnchorMediaUploadQueueStore(
      preferences: preferences,
    );
  });
}

abstract class AnchorMediaUploadQueueStore {
  Map<String, AnchorMediaUploadEntry> loadUploadEntries();

  void saveUploadEntries(Map<String, AnchorMediaUploadEntry> entries);
}

class InMemoryAnchorMediaUploadQueueStore
    implements AnchorMediaUploadQueueStore {
  Map<String, AnchorMediaUploadEntry> _entries =
      const <String, AnchorMediaUploadEntry>{};

  @override
  Map<String, AnchorMediaUploadEntry> loadUploadEntries() {
    return Map<String, AnchorMediaUploadEntry>.unmodifiable(_entries);
  }

  @override
  void saveUploadEntries(Map<String, AnchorMediaUploadEntry> entries) {
    _entries = Map<String, AnchorMediaUploadEntry>.unmodifiable(entries);
  }
}

class SharedPreferencesAnchorMediaUploadQueueStore
    implements AnchorMediaUploadQueueStore {
  const SharedPreferencesAnchorMediaUploadQueueStore({
    required SharedPreferences preferences,
    String key = _anchorMediaUploadQueueKey,
  })  : _preferences = preferences,
        _key = key;

  final SharedPreferences _preferences;
  final String _key;

  @override
  Map<String, AnchorMediaUploadEntry> loadUploadEntries() {
    final encodedQueue = _preferences.getString(_key);
    if (encodedQueue == null || encodedQueue.trim().isEmpty) {
      return const <String, AnchorMediaUploadEntry>{};
    }

    try {
      final decoded = jsonDecode(encodedQueue);
      if (decoded is! List) {
        clear();
        return const <String, AnchorMediaUploadEntry>{};
      }

      final entries = <String, AnchorMediaUploadEntry>{};
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final entry = _entryFromJson(Map<String, Object?>.from(item));
        if (entry != null) {
          entries[entry.key] = entry;
        }
      }
      return Map<String, AnchorMediaUploadEntry>.unmodifiable(entries);
    } on Object {
      clear();
      return const <String, AnchorMediaUploadEntry>{};
    }
  }

  @override
  void saveUploadEntries(Map<String, AnchorMediaUploadEntry> entries) {
    if (entries.isEmpty) {
      unawaited(_preferences.remove(_key));
      return;
    }
    unawaited(
      _preferences.setString(
        _key,
        jsonEncode([
          for (final entry in entries.values) _entryToJson(entry),
        ]),
      ),
    );
  }

  void clear() {
    unawaited(_preferences.remove(_key));
  }
}

Map<String, Object?> _entryToJson(AnchorMediaUploadEntry entry) {
  return <String, Object?>{
    'schemaVersion': 1,
    'key': entry.key,
    'memoryId': entry.memoryId,
    'mediaId': entry.mediaId,
    'status': entry.status.name,
    'retryCount': entry.retryCount,
    'updatedAt': entry.updatedAt?.toIso8601String(),
    'errorMessage': entry.errorMessage,
  };
}

AnchorMediaUploadEntry? _entryFromJson(Map<String, Object?> json) {
  final key = json['key'];
  final memoryId = json['memoryId'];
  if (key is! String ||
      key.trim().isEmpty ||
      memoryId is! String ||
      memoryId.trim().isEmpty) {
    return null;
  }

  return AnchorMediaUploadEntry(
    key: key,
    memoryId: memoryId,
    mediaId: json['mediaId'] as String?,
    status: _enumByName(
      AnchorMediaUploadStatus.values,
      json['status'],
      AnchorMediaUploadStatus.queued,
    ),
    retryCount: _int(json['retryCount'], 0),
    updatedAt: _date(json['updatedAt']),
    errorMessage: json['errorMessage'] as String?,
  );
}

T _enumByName<T extends Enum>(
  Iterable<T> values,
  Object? name,
  T fallback,
) {
  if (name is! String) {
    return fallback;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

int _int(Object? value, int fallback) {
  if (value is num && value.isFinite) {
    return value.toInt().clamp(0, 1 << 31);
  }
  return fallback;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
