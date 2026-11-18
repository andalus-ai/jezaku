import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/profile/models/profile_rules.dart';
import 'package:jejaku/features/profile/models/profile_stats.dart';
import 'package:jejaku/features/profile/models/user_profile.dart';
import 'package:jejaku/features/profile/services/user_profile_store.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

final userProfileProvider =
    NotifierProvider<UserProfileController, UserProfile>(
  UserProfileController.new,
);

/// Real counts from local data; nothing here is a placeholder.
final profileStatsProvider = Provider<ProfileStats>((ref) {
  return ProfileStats(
    memories: ref.watch(nearbyAnchorsProvider).length,
    walls: ref.watch(arWallsProvider).length,
    pendingSync: ref.watch(pendingSyncMemoriesProvider).length,
  );
});

class UserProfileController extends Notifier<UserProfile> {
  static const _defaultProfile = UserProfile(
    displayName: 'Jejaku Explorer',
    handle: '@jejaku.explorer',
  );

  @override
  UserProfile build() {
    return ref.read(userProfileStoreProvider).load() ?? _defaultProfile;
  }

  /// Applies an edit. Blank or invalid fields keep their current value, so a
  /// bad edit can never leave the profile empty; the edit dialog reports the
  /// reasons through [ProfileRules] before it gets here.
  void updateProfile({
    required String displayName,
    required String handle,
  }) {
    // Over-long names are shortened rather than refused: the dialog already
    // stops typing at the limit, so this only guards other callers.
    final nextName = ProfileRules.truncateDisplayName(displayName);
    final nextHandle = ProfileRules.handleError(handle) == null
        ? ProfileRules.normalizeHandle(handle)
        : '';

    final next = state.copyWith(
      displayName: nextName.isEmpty ? state.displayName : nextName,
      handle: nextHandle.isEmpty ? state.handle : nextHandle,
    );
    state = next;
    ref.read(userProfileStoreProvider).save(next);
  }
}
