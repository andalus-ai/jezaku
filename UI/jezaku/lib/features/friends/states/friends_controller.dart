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
    this.userId,
    this.ids = const <String>{},
    this.loaded = false,
    this.loading = false,
    this.failure,
  });

  /// Whose friends [ids] are. Anything that reads [ids] must check it against
  /// the signed-in user (see `friendIdsProvider`), so one user never sees
  /// another's friends even for a moment.
  final String? userId;

  /// Ids of that user's friends, from the last good answer. Empty until the
  /// first answer: friends-only frames of others stay hidden.
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
/// viewer's location updates. Forgets the friends when the user changes.
final friendsAutoRefreshProvider = Provider<void>((ref) {
  final controller = ref.read(friendsProvider.notifier);

  ref.listen(signedInUserIdProvider, (_, userId) {
    controller.forgetUnlessFor(userId);
    controller.refreshIfNeeded();
  });
  ref.listen(viewerLocationProvider, (_, __) => controller.refreshIfNeeded());
  controller.refreshIfNeeded();
});

class FriendsController extends Notifier<FriendsState> {
  /// Ask again after this long. Short enough that a removed friend stops
  /// seeing your friends-only frames soon; long enough not to hammer the
  /// service.
  static const maxAge = Duration(minutes: 5);

  DateTime? _lastAttemptAt;
  String? _inFlightFor;

  @override
  FriendsState build() => const FriendsState();

  /// Drops friends that belong to someone else (sign-out, or another user
  /// signing in).
  void forgetUnlessFor(String? userId) {
    if (state.userId != userId) {
      _lastAttemptAt = null;
      state = FriendsState(userId: userId);
    }
  }

  Future<void> refreshIfNeeded({DateTime? now}) async {
    final api = ref.read(socialApiProvider);
    final userId = ref.read(signedInUserIdProvider);
    if (api == null || userId == null || _inFlightFor == userId) {
      return;
    }
    forgetUnlessFor(userId);
    final at = now ?? DateTime.now();
    final last = _lastAttemptAt;
    if (last != null && at.difference(last) < maxAge) {
      return;
    }

    _inFlightFor = userId;
    _lastAttemptAt = at;
    state = FriendsState(
      userId: userId,
      ids: state.ids,
      loaded: state.loaded,
      loading: true,
    );
    try {
      final ids = await api.friendIds(userId);
      if (_stillCurrent(userId)) {
        state = FriendsState(userId: userId, ids: ids, loaded: true);
      }
    } on ApiFailure catch (failure) {
      _fail(userId, failure.reason);
    } on Object {
      _fail(userId, ApiFailureReason.server);
    } finally {
      if (_inFlightFor == userId) {
        _inFlightFor = null;
      }
    }
  }

  void _fail(String userId, ApiFailureReason reason) {
    if (_stillCurrent(userId)) {
      state = FriendsState(
        userId: userId,
        ids: state.ids,
        loaded: state.loaded,
        failure: reason,
      );
    }
  }

  bool _stillCurrent(String userId) {
    return ref.mounted &&
        ref.read(signedInUserIdProvider) == userId &&
        state.userId == userId;
  }
}
