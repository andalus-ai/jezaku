import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/sync/models/anchor_sync_delivery_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _anchorSyncDeliveryLogKey = 'jejaku.anchor_sync_delivery_log';

final anchorSyncDeliveryLogStoreProvider =
    Provider<AnchorSyncDeliveryLogStore>((ref) {
  return InMemoryAnchorSyncDeliveryLogStore();
});

persistentAnchorSyncDeliveryLogStoreOverride({
  required SharedPreferences preferences,
}) {
  return anchorSyncDeliveryLogStoreProvider.overrideWith((ref) {
    return SharedPreferencesAnchorSyncDeliveryLogStore(
      preferences: preferences,
    );
  });
}

abstract class AnchorSyncDeliveryLogStore {
  List<AnchorSyncDeliveryEntry> loadEntries();

  void saveEntries(List<AnchorSyncDeliveryEntry> entries);
}

class InMemoryAnchorSyncDeliveryLogStore implements AnchorSyncDeliveryLogStore {
  List<AnchorSyncDeliveryEntry> _entries = const <AnchorSyncDeliveryEntry>[];

  @override
  List<AnchorSyncDeliveryEntry> loadEntries() {
    return List<AnchorSyncDeliveryEntry>.unmodifiable(_entries);
  }

  @override
  void saveEntries(List<AnchorSyncDeliveryEntry> entries) {
    _entries = List<AnchorSyncDeliveryEntry>.unmodifiable(entries);
  }
}

class SharedPreferencesAnchorSyncDeliveryLogStore
    implements AnchorSyncDeliveryLogStore {
  const SharedPreferencesAnchorSyncDeliveryLogStore({
    required SharedPreferences preferences,
    String key = _anchorSyncDeliveryLogKey,
  })  : _preferences = preferences,
        _key = key;

  final SharedPreferences _preferences;
  final String _key;

  @override
  List<AnchorSyncDeliveryEntry> loadEntries() {
    final encodedLog = _preferences.getString(_key);
    if (encodedLog == null || encodedLog.trim().isEmpty) {
      return const <AnchorSyncDeliveryEntry>[];
    }

    try {
      final decoded = jsonDecode(encodedLog);
      if (decoded is! List) {
        _quarantine(encodedLog);
        return const <AnchorSyncDeliveryEntry>[];
      }

      final entries = <AnchorSyncDeliveryEntry>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final entry = _entryFromJson(Map<String, Object?>.from(item));
        if (entry != null) {
          entries.add(entry);
        }
      }
      return List<AnchorSyncDeliveryEntry>.unmodifiable(entries);
    } on Object {
      _quarantine(encodedLog);
      return const <AnchorSyncDeliveryEntry>[];
    }
  }

  @override
  void saveEntries(List<AnchorSyncDeliveryEntry> entries) {
    if (entries.isEmpty) {
      unawaited(_preferences.remove(_key));
      return;
    }
    unawaited(
      _preferences.setString(
        _key,
        jsonEncode([
          for (final entry in entries) _entryToJson(entry),
        ]),
      ),
    );
  }

  /// Where unreadable log data is kept instead of being silently dropped.
  String get corruptBackupKey => '$_key.corrupt';

  void _quarantine(String rawValue) {
    unawaited(_preferences.setString(corruptBackupKey, rawValue));
    clear();
  }

  void clear() {
    unawaited(_preferences.remove(_key));
  }
}

Map<String, Object?> _entryToJson(AnchorSyncDeliveryEntry entry) {
  return <String, Object?>{
    'schemaVersion': 1,
    'id': entry.id,
    'attemptedAt': entry.attemptedAt.toUtc().toIso8601String(),
    'status': entry.status.wireName,
    'tenantRealm': entry.tenantRealm,
    'endpointLabel': entry.endpointLabel,
    'batchType': entry.batchType.wireName,
    'idempotencyKey': entry.idempotencyKey,
    'payloadFingerprint': entry.payloadFingerprint,
    'itemCount': entry.itemCount,
    'mediaCount': entry.mediaCount,
    'message': entry.message,
  };
}

AnchorSyncDeliveryEntry? _entryFromJson(Map<String, Object?> json) {
  final id = json['id'];
  final idempotencyKey = json['idempotencyKey'];
  final payloadFingerprint = json['payloadFingerprint'];
  if (id is! String ||
      id.trim().isEmpty ||
      idempotencyKey is! String ||
      idempotencyKey.trim().isEmpty ||
      payloadFingerprint is! String ||
      payloadFingerprint.trim().isEmpty) {
    return null;
  }

  return AnchorSyncDeliveryEntry(
    id: id,
    attemptedAt: _date(json['attemptedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    status: anchorSyncDeliveryStatusFromWireName(json['status']),
    tenantRealm: _string(json['tenantRealm'], 'jezaku'),
    endpointLabel: _string(json['endpointLabel'], 'local device'),
    batchType: anchorSyncBatchTypeFromWireName(json['batchType']),
    idempotencyKey: idempotencyKey,
    payloadFingerprint: payloadFingerprint,
    itemCount: _int(json['itemCount'], 0),
    mediaCount: _int(json['mediaCount'], 0),
    message: _string(json['message'], ''),
  );
}

int _int(Object? value, int fallback) {
  if (value is num && value.isFinite) {
    return value.toInt().clamp(0, 1 << 31);
  }
  return fallback;
}

String _string(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return fallback;
}

DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
