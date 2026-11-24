import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/friends/services/social_api.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';

/// The social service client, or null when this build has no social service
/// (demo builds, or no `JEZAKU_SOCIAL_URL`). Callers treat null as "no
/// friends known".
final socialApiProvider = Provider<SocialApi?>((ref) => null);

class FriendsState {
  const FriendsState({
    this.ids = const <String>{},
    this.loaded = false,
    this.loading = false,
    this.failure,
  });

  /// Ids of the signed-in user's friends, from the last good answer. Empty
  /// until the first answer: friends-only frames of others stay hidden.
  final Set<String> ids;

  /// Whether a good answer has arrived since the user signed in.
  final bool loaded;
  final bool loading;

  /// Why the last attempt failed, until the next one succeeds. [ids] keep the
  /// last good answer.
  final ApiFailureReason? failure;
}

final friendsProvider =
    NotifierProvider<FriendsController, FriendsState>(FriendsController.new);

/// Keeps [friendsProvider] fresh while something watches it: loads when the
/// user signs in and checks again, at most every few minutes, whenever the
/// viewer's location updates.
final friendsAutoRefreshProvider = Provider<void>((ref) {
  void refresh() => ref.read(friendsProvider.notifier).refreshIfNeeded();

  ref.listen(signedInUserIdProvider, (_, __) => refresh());
  ref.listen(viewerLocationProvider, (_, __) => refresh());
  refresh();
});

class FriendsController extends Notifier<FriendsState> {
  /// Ask again after this long. Short enough that a removed friend stops
  /// seeing your friends-only frames soon; long enough not to hammer the
  /// service.
  static const maxAge = Duration(minutes: 5);

  DateTime? _lastAttemptAt;
  bool _inFlight = false;

  @override
  FriendsState build() {
    // Another user (or nobody) must never inherit the last user's friends.
    ref.watch(signedInUserIdProvider);
    _lastAttemptAt = null;
    _inFlight = false;
    return const FriendsState();
  }

  Future<void> refreshIfNeeded({DateTime? now}) async {
    final api = ref.read(socialApiProvider);
    final userId = ref.read(signedInUserIdProvider);
    if (api == null || userId == null || _inFlight) {
      return;
    }
    final at = now ?? DateTime.now();
    final last = _lastAttemptAt;
    if (last != null && at.difference(last) < maxAge) {
      return;
    }

    _inFlight = true;
    _lastAttemptAt = at;
    state = FriendsState(ids: state.ids, loaded: state.loaded, loading: true);
    try {
      final ids = await api.friendIds(userId);
      if (_stillCurrent(userId)) {
        state = FriendsState(ids: ids, loaded: true);
      }
    } on ApiFailure catch (failure) {
      if (_stillCurrent(userId)) {
        state = FriendsState(
          ids: state.ids,
          loaded: state.loaded,
          failure: failure.reason,
        );
      }
    } on Object {
      if (_stillCurrent(userId)) {
        state = FriendsState(
          ids: state.ids,
          loaded: state.loaded,
          failure: ApiFailureReason.server,
        );
      }
    } finally {
      _inFlight = false;
    }
  }

  bool _stillCurrent(String userId) {
    return ref.mounted && ref.read(signedInUserIdProvider) == userId;
  }
}
