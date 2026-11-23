import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/services/ar_model_asset_cache_provider.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/states/sample_data_provider.dart';
import 'package:jejaku/features/settings/models/app_settings.dart';
import 'package:jejaku/features/settings/services/app_settings_store.dart';

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);

class AppSettingsController extends Notifier<AppSettings> {
  /// Longest account name kept in the block list.
  static const maxBlockedAccountNameLength = 60;

  @override
  AppSettings build() {
    // Fabricated blocked accounts and cache size only exist with sample data;
    // a shipped app starts with an honest empty block list.
    final showSamples = ref.read(sampleDataEnabledProvider);
    final defaults = AppSettings(
      nearbyNotifications: true,
      privateByDefault: false,
      highAccuracyMode: true,
      familyLocationAlerts: true,
      weeklyGuardianDigest: true,
      approvalReminders: true,
      cachedMediaMb: showSamples ? 342 : 0,
      sharePreciseLocation: true,
      commentsEnabledByDefault: true,
      profileDiscoverable: true,
      blockedAccounts:
          showSamples ? const ['Spam Mapper', 'Unknown Visitor'] : const [],
    );
    return ref.read(appSettingsStoreProvider).load(fallback: defaults) ??
        defaults;
  }

  void _update(AppSettings next) {
    state = next;
    ref.read(appSettingsStoreProvider).save(next);
  }

  void setNearbyNotifications(bool value) {
    _update(state.copyWith(nearbyNotifications: value));
  }

  void setPrivateByDefault(bool value) {
    _update(state.copyWith(privateByDefault: value));
  }

  void setDefaultFrame({required String lookId, int? colorValue}) {
    _update(
      state.copyWith(
        defaultFrameLookId: lookId,
        defaultFrameColorValue: colorValue,
      ),
    );
  }

  void setHighAccuracyMode(bool value) {
    _update(state.copyWith(highAccuracyMode: value));
  }

  void setFamilyLocationAlerts(bool value) {
    _update(state.copyWith(familyLocationAlerts: value));
  }

  void setWeeklyGuardianDigest(bool value) {
    _update(state.copyWith(weeklyGuardianDigest: value));
  }

  void setApprovalReminders(bool value) {
    _update(state.copyWith(approvalReminders: value));
  }

  void clearCachedMedia() {
    ref.read(anchorMediaRepositoryProvider).clearCachedMedia();
    _update(state.copyWith(cachedMediaMb: 0));
    unawaited(_clearARModelCache());
  }

  Future<void> _clearARModelCache() async {
    try {
      await ref.read(arModelAssetCacheProvider).clear();
      ref.read(arModelAssetCacheRevisionProvider.notifier).bump();
    } on Object {
      // Media cache clearing should still succeed if the model cache is busy.
    }
  }

  void setSharePreciseLocation(bool value) {
    _update(state.copyWith(sharePreciseLocation: value));
  }

  void setCommentsEnabledByDefault(bool value) {
    _update(state.copyWith(commentsEnabledByDefault: value));
  }

  void setProfileDiscoverable(bool value) {
    _update(state.copyWith(profileDiscoverable: value));
  }

  void blockAccount(String accountName) {
    var trimmedName = accountName.trim();
    if (trimmedName.length > maxBlockedAccountNameLength) {
      trimmedName = trimmedName.substring(0, maxBlockedAccountNameLength);
    }
    if (trimmedName.isEmpty || state.isAccountBlocked(trimmedName)) {
      return;
    }

    _update(state.copyWith(
      blockedAccounts: [...state.blockedAccounts, trimmedName],
    ));
  }

  void unblockAccount(String accountName) {
    _update(state.copyWith(
      blockedAccounts: [
        for (final account in state.blockedAccounts)
          if (account != accountName) account,
      ],
    ));
  }
}
