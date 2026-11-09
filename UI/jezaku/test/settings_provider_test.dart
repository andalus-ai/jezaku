import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';

void main() {
  test('settings controller updates app and family safety preferences', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(appSettingsProvider.notifier);
    controller
      ..setNearbyNotifications(false)
      ..setPrivateByDefault(true)
      ..setHighAccuracyMode(false)
      ..setFamilyLocationAlerts(false)
      ..setWeeklyGuardianDigest(false)
      ..setApprovalReminders(false);

    final settings = container.read(appSettingsProvider);

    expect(settings.nearbyNotifications, isFalse);
    expect(settings.privateByDefault, isTrue);
    expect(settings.highAccuracyMode, isFalse);
    expect(settings.familyLocationAlerts, isFalse);
    expect(settings.weeklyGuardianDigest, isFalse);
    expect(settings.approvalReminders, isFalse);
  });

  test('settings controller updates privacy and safety preferences', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(appSettingsProvider.notifier);
    final initialSettings = container.read(appSettingsProvider);

    expect(initialSettings.sharePreciseLocation, isTrue);
    expect(initialSettings.commentsEnabledByDefault, isTrue);
    expect(initialSettings.profileDiscoverable, isTrue);
    expect(initialSettings.blockedAccounts, contains('Spam Mapper'));
    expect(initialSettings.blockedAccountsLabel, '2 blocked accounts');

    controller
      ..setSharePreciseLocation(false)
      ..setCommentsEnabledByDefault(false)
      ..setProfileDiscoverable(false)
      ..unblockAccount('Spam Mapper');

    final settings = container.read(appSettingsProvider);

    expect(settings.sharePreciseLocation, isFalse);
    expect(settings.commentsEnabledByDefault, isFalse);
    expect(settings.profileDiscoverable, isFalse);
    expect(settings.blockedAccounts, isNot(contains('Spam Mapper')));
    expect(settings.blockedAccountsLabel, '1 blocked account');
    expect(
      settings.privacySafetySummary,
      'Approximate location only - Comments off - 1 blocked account',
    );
  });

  test('settings controller clears cached media', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final mediaRepository = container.read(anchorMediaRepositoryProvider);

    expect(container.read(appSettingsProvider).cachedMediaMb, 342);
    final storedAttachment = mediaRepository.storeAttachment(
      const AnchorMediaAttachment(type: AnchorMediaType.arSnapshot),
    );
    expect(mediaRepository.mediaById(storedAttachment.mediaId!), isNotNull);
    expect(mediaRepository.cachedMediaCount, 1);

    container.read(appSettingsProvider.notifier).clearCachedMedia();

    expect(container.read(appSettingsProvider).cachedMediaMb, 0);
    expect(mediaRepository.allMedia, isEmpty);
    expect(mediaRepository.cachedMediaCount, 0);
  });

  test('settings controller blocks and unblocks accounts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(appSettingsProvider.notifier);

    expect(
        container.read(appSettingsProvider).isAccountBlocked('maya'), isFalse);

    controller.blockAccount('maya');
    controller.blockAccount('MAYA');
    expect(
        container.read(appSettingsProvider).isAccountBlocked('maya'), isTrue);
    expect(
      container
          .read(appSettingsProvider)
          .blockedAccounts
          .where((account) => account.toLowerCase() == 'maya'),
      hasLength(1),
    );

    controller.unblockAccount('maya');
    expect(
        container.read(appSettingsProvider).isAccountBlocked('maya'), isFalse);
  });
}
