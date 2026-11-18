import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/profile/models/user_profile.dart';
import 'package:jejaku/features/profile/services/user_profile_store.dart';
import 'package:jejaku/features/profile/states/profile_providers.dart';
import 'package:jejaku/features/settings/models/app_settings.dart';
import 'package:jejaku/features/settings/services/app_settings_store.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container(SharedPreferences preferences) {
  final container = ProviderContainer(
    overrides: [
      persistentAppSettingsStoreOverride(preferences: preferences),
      persistentUserProfileStoreOverride(preferences: preferences),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<SharedPreferences> _preferences([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('settings persistence', () {
    test('changes survive a restart', () async {
      final preferences = await _preferences();
      final first = _container(preferences);
      first.read(appSettingsProvider.notifier)
        ..setPrivateByDefault(true)
        ..setSharePreciseLocation(false)
        ..blockAccount('  Pest  ');

      final second = _container(preferences);
      final restored = second.read(appSettingsProvider);

      expect(restored.privateByDefault, isTrue);
      expect(restored.sharePreciseLocation, isFalse);
      expect(restored.blockedAccounts, contains('Pest'));
      expect(restored.nearbyNotifications, isTrue);
    });

    test('unblocking is remembered too', () async {
      final preferences = await _preferences();
      final first = _container(preferences);
      first.read(appSettingsProvider.notifier).unblockAccount('Spam Mapper');

      final restored = _container(preferences).read(appSettingsProvider);

      expect(restored.blockedAccounts, isNot(contains('Spam Mapper')));
      expect(restored.blockedAccounts, contains('Unknown Visitor'));
    });

    test('the cache size is measured, not persisted', () async {
      final settings = AppSettings.fromJson(
        {'cachedMediaMb': 9999, 'privateByDefault': true},
        fallback: const AppSettings(
          nearbyNotifications: true,
          privateByDefault: false,
          highAccuracyMode: true,
          familyLocationAlerts: true,
          weeklyGuardianDigest: true,
          approvalReminders: true,
          cachedMediaMb: 12,
          sharePreciseLocation: true,
          commentsEnabledByDefault: true,
          profileDiscoverable: true,
          blockedAccounts: [],
        ),
      );

      expect(settings.cachedMediaMb, 12);
      expect(settings.privateByDefault, isTrue);
      expect(settings.toJson().containsKey('cachedMediaMb'), isFalse);
    });

    test('missing and mistyped keys fall back to defaults', () async {
      final preferences = await _preferences({
        'jejaku.app_settings':
            '{"privateByDefault": true, "highAccuracyMode": "yes", '
                '"blockedAccounts": ["Ok", 5, "  "]}',
      });

      final restored = _container(preferences).read(appSettingsProvider);

      expect(restored.privateByDefault, isTrue);
      expect(restored.highAccuracyMode, isTrue, reason: 'wrong type ignored');
      expect(restored.blockedAccounts, ['Ok']);
    });

    test('corrupt data is quarantined and defaults are used', () async {
      final preferences = await _preferences({
        'jejaku.app_settings': '{not json',
      });

      final restored = _container(preferences).read(appSettingsProvider);

      expect(restored.privateByDefault, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(preferences.getString('jejaku.app_settings'), isNull);
      expect(preferences.getString('jejaku.app_settings.corrupt'), '{not json');
    });

    test('very long names are capped when blocking', () async {
      final container = _container(await _preferences());
      container.read(appSettingsProvider.notifier).blockAccount('x' * 200);

      final blocked = container.read(appSettingsProvider).blockedAccounts;

      expect(
        blocked.last.length,
        AppSettingsController.maxBlockedAccountNameLength,
      );
    });
  });

  group('profile persistence', () {
    test('an edit survives a restart', () async {
      final preferences = await _preferences();
      _container(preferences).read(userProfileProvider.notifier).updateProfile(
            displayName: 'Alya Trail',
            handle: 'Alya T',
          );

      final restored = _container(preferences).read(userProfileProvider);

      expect(restored.displayName, 'Alya Trail');
      expect(restored.handle, '@alya.t');
    });

    test('invalid handles and names keep the current values', () async {
      final container = _container(await _preferences());
      final controller = container.read(userProfileProvider.notifier);

      controller.updateProfile(displayName: 'Alya', handle: 'ab');
      expect(container.read(userProfileProvider).handle, '@jejaku.explorer');
      expect(container.read(userProfileProvider).displayName, 'Alya');

      controller.updateProfile(displayName: '   ', handle: '@admin');
      expect(container.read(userProfileProvider).displayName, 'Alya');
      expect(container.read(userProfileProvider).handle, '@jejaku.explorer');
    });

    test('long names are truncated', () async {
      final container = _container(await _preferences());
      container.read(userProfileProvider.notifier).updateProfile(
            displayName: 'n' * 80,
            handle: '',
          );

      expect(container.read(userProfileProvider).displayName.length, 40);
    });

    test('unusable saved data falls back to the default profile', () async {
      final preferences = await _preferences({
        'jejaku.user_profile': '{"displayName": "", "handle": "@x"}',
      });

      final profile = _container(preferences).read(userProfileProvider);

      expect(profile.displayName, 'Jejaku Explorer');
      await Future<void>.delayed(Duration.zero);
      expect(
        preferences.getString('jejaku.user_profile.corrupt'),
        isNotNull,
      );
    });

    test('tryFromJson rejects wrong types', () {
      expect(UserProfile.tryFromJson({'displayName': 1, 'handle': 'x'}), isNull);
    });
  });
}
