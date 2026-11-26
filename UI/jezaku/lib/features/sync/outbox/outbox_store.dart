import 'dart:convert';

import 'package:jejaku/features/sync/outbox/outbox_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the outbox keeps its entries so they survive the app being closed.
abstract class OutboxStore {
  List<OutboxEntry> load();

  Future<void> save(List<OutboxEntry> entries);
}

class InMemoryOutboxStore implements OutboxStore {
  InMemoryOutboxStore([List<OutboxEntry> initial = const <OutboxEntry>[]])
      : _entries = List<OutboxEntry>.of(initial);

  List<OutboxEntry> _entries;

  @override
  List<OutboxEntry> load() => List<OutboxEntry>.unmodifiable(_entries);

  @override
  Future<void> save(List<OutboxEntry> entries) async {
    _entries = List<OutboxEntry>.of(entries);
  }
}

const _outboxKey = 'jejaku.frame_outbox.v1';

class SharedPreferencesOutboxStore implements OutboxStore {
  const SharedPreferencesOutboxStore({
    required SharedPreferences preferences,
    String key = _outboxKey,
  })  : _preferences = preferences,
        _key = key;

  final SharedPreferences _preferences;
  final String _key;

  /// Entries that cannot be read are skipped one by one: one damaged record
  /// must not hide the other pending frames.
  @override
  List<OutboxEntry> load() {
    final encoded = _preferences.getString(_key);
    if (encoded == null || encoded.trim().isEmpty) {
      return const <OutboxEntry>[];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return const <OutboxEntry>[];
    }
    if (decoded is! List) {
      return const <OutboxEntry>[];
    }
    final entries = <OutboxEntry>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      try {
        entries.add(OutboxEntry.fromJson(Map<String, Object?>.from(item)));
      } on FormatException {
        continue;
      }
    }
    return List<OutboxEntry>.unmodifiable(entries);
  }

  @override
  Future<void> save(List<OutboxEntry> entries) async {
    await _preferences.setString(
      _key,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }
}
