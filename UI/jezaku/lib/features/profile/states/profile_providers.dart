import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/profile/models/user_profile.dart';

final userProfileProvider =
    NotifierProvider<UserProfileController, UserProfile>(
  UserProfileController.new,
);

class UserProfileController extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    return const UserProfile(
      displayName: 'Jejaku Explorer',
      handle: '@jejaku.explorer',
    );
  }

  void updateProfile({
    required String displayName,
    required String handle,
  }) {
    final nextName = displayName.trim();
    final nextHandle = _normalizeHandle(handle);

    state = state.copyWith(
      displayName: nextName.isEmpty ? state.displayName : nextName,
      handle: nextHandle.isEmpty ? state.handle : nextHandle,
    );
  }

  String _normalizeHandle(String value) {
    final trimmed = value.trim().toLowerCase();
    final withoutAt = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    final dotted = withoutAt.replaceAll(RegExp(r'\s+'), '.');
    final normalized = dotted.replaceAll(RegExp(r'[^a-z0-9._]'), '');

    if (normalized.isEmpty) {
      return '';
    }
    return '@$normalized';
  }
}
