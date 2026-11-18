import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/settings/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appSettingsKey = 'jejaku.app_settings';

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return InMemoryAppSettingsStore();
});

/// Where the user's preferences live between launches.
abstract class AppSettingsStore {
  /// The saved settings, or `null` when nothing usable is saved.
  /// Keys missing from older saves take their value from [fallback].
  AppSettings? load({required AppSettings fallback});

  void save(AppSettings settings);
}

class InMemoryAppSettingsStore implements AppSettingsStore {
  AppSettings? _saved;

  @override
  AppSettings? load({required AppSettings fallback}) => _saved;

  @override
  void save(AppSettings settings) {
    _saved = settings;
  }
}

class SharedPreferencesAppSettingsStore implements AppSettingsStore {
  const SharedPreferencesAppSettingsStore({
    required SharedPreferences preferences,
    String key = _appSettingsKey,
  })  : _preferences = preferences,
        _key = key;

  final SharedPreferences _preferences;
  final String _key;

  @override
  AppSettings? load({required AppSettings fallback}) {
    final encoded = _preferences.getString(_key);
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return AppSettings.fromJson(decoded, fallback: fallback);
      }
    } on FormatException {
      // Fall through to quarantine below.
    }
    // Keep unreadable data for diagnosis rather than silently erasing it.
    unawaited(_preferences.setString('$_key.corrupt', encoded));
    unawaited(_preferences.remove(_key));
    return null;
  }

  @override
  void save(AppSettings settings) {
    unawaited(_preferences.setString(_key, jsonEncode(settings.toJson())));
  }
}

persistentAppSettingsStoreOverride({
  required SharedPreferences preferences,
}) {
  return appSettingsStoreProvider.overrideWith((ref) {
    return SharedPreferencesAppSettingsStore(preferences: preferences);
  });
}
