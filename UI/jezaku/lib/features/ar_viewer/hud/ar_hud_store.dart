import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/hud/ar_hud_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _arHudKey = 'jejaku.ar_hud';

final arHudStoreProvider = Provider<ARHudStore>((ref) {
  return InMemoryARHudStore();
});

/// Remembers which HUD panels the viewer turned on or off.
abstract class ARHudStore {
  /// The saved layout, or the default view when nothing usable is saved.
  ARHudState load();

  void save(ARHudState state);
}

class InMemoryARHudStore implements ARHudStore {
  ARHudState _state = const ARHudState();

  @override
  ARHudState load() => _state;

  @override
  void save(ARHudState state) {
    // Round-trip so this behaves like the persistent store: Hide UI is not
    // remembered.
    _state = ARHudState.fromJson(state.toJson());
  }
}

class SharedPreferencesARHudStore implements ARHudStore {
  const SharedPreferencesARHudStore({
    required SharedPreferences preferences,
    String key = _arHudKey,
  })  : _preferences = preferences,
        _key = key;

  final SharedPreferences _preferences;
  final String _key;

  @override
  ARHudState load() {
    final encoded = _preferences.getString(_key);
    if (encoded == null || encoded.trim().isEmpty) {
      return const ARHudState();
    }
    try {
      return ARHudState.fromJson(jsonDecode(encoded));
    } on FormatException {
      return const ARHudState();
    }
  }

  @override
  void save(ARHudState state) {
    unawaited(_preferences.setString(_key, jsonEncode(state.toJson())));
  }
}

persistentARHudStoreOverride({
  required SharedPreferences preferences,
}) {
  return arHudStoreProvider.overrideWith((ref) {
    return SharedPreferencesARHudStore(preferences: preferences);
  });
}
