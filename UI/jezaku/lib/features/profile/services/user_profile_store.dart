import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/profile/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userProfileKey = 'jejaku.user_profile';

final userProfileStoreProvider = Provider<UserProfileStore>((ref) {
  return InMemoryUserProfileStore();
});

/// Where the user's own profile lives between launches.
abstract class UserProfileStore {
  UserProfile? load();

  void save(UserProfile profile);
}

class InMemoryUserProfileStore implements UserProfileStore {
  UserProfile? _saved;

  @override
  UserProfile? load() => _saved;

  @override
  void save(UserProfile profile) {
    _saved = profile;
  }
}

class SharedPreferencesUserProfileStore implements UserProfileStore {
  const SharedPreferencesUserProfileStore({
    required SharedPreferences preferences,
    String key = _userProfileKey,
  })  : _preferences = preferences,
        _key = key;

  final SharedPreferences _preferences;
  final String _key;

  @override
  UserProfile? load() {
    final encoded = _preferences.getString(_key);
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        final profile = UserProfile.tryFromJson(decoded);
        if (profile != null) {
          return profile;
        }
      }
    } on FormatException {
      // Fall through to quarantine below.
    }
    unawaited(_preferences.setString('$_key.corrupt', encoded));
    unawaited(_preferences.remove(_key));
    return null;
  }

  @override
  void save(UserProfile profile) {
    unawaited(_preferences.setString(_key, jsonEncode(profile.toJson())));
  }
}

persistentUserProfileStoreOverride({
  required SharedPreferences preferences,
}) {
  return userProfileStoreProvider.overrideWith((ref) {
    return SharedPreferencesUserProfileStore(preferences: preferences);
  });
}
