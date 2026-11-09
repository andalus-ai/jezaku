import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/services/ar_model_asset_cache_provider.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/settings/models/app_settings.dart';

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return const AppSettings(
      nearbyNotifications: true,
      privateByDefault: false,
      highAccuracyMode: true,
      familyLocationAlerts: true,
      weeklyGuardianDigest: true,
      approvalReminders: true,
      cachedMediaMb: 342,
      sharePreciseLocation: true,
      commentsEnabledByDefault: true,
      profileDiscoverable: true,
      blockedAccounts: ['Spam Mapper', 'Unknown Visitor'],
    );
  }

  void setNearbyNotifications(bool value) {
    state = state.copyWith(nearbyNotifications: value);
  }

  void setPrivateByDefault(bool value) {
    state = state.copyWith(privateByDefault: value);
  }

  void setHighAccuracyMode(bool value) {
    state = state.copyWith(highAccuracyMode: value);
  }

  void setFamilyLocationAlerts(bool value) {
    state = state.copyWith(familyLocationAlerts: value);
  }

  void setWeeklyGuardianDigest(bool value) {
    state = state.copyWith(weeklyGuardianDigest: value);
  }

  void setApprovalReminders(bool value) {
    state = state.copyWith(approvalReminders: value);
  }

  void clearCachedMedia() {
    ref.read(anchorMediaRepositoryProvider).clearCachedMedia();
    state = state.copyWith(cachedMediaMb: 0);
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
    state = state.copyWith(sharePreciseLocation: value);
  }

  void setCommentsEnabledByDefault(bool value) {
    state = state.copyWith(commentsEnabledByDefault: value);
  }

  void setProfileDiscoverable(bool value) {
    state = state.copyWith(profileDiscoverable: value);
  }

  void blockAccount(String accountName) {
    final trimmedName = accountName.trim();
    if (trimmedName.isEmpty || state.isAccountBlocked(trimmedName)) {
      return;
    }

    state = state.copyWith(
      blockedAccounts: [...state.blockedAccounts, trimmedName],
    );
  }

  void unblockAccount(String accountName) {
    state = state.copyWith(
      blockedAccounts: [
        for (final account in state.blockedAccounts)
          if (account != accountName) account,
      ],
    );
  }
}
