import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_providers.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/remote_frames/models/remote_frame.dart';
import 'package:jejaku/features/remote_frames/services/memory_api.dart';
import 'package:jejaku/features/remote_frames/services/remote_frame_mapper.dart';
import 'package:jejaku/features/remote_frames/services/remote_media_loader.dart';
import 'package:jejaku/features/remote_frames/states/memory_api_provider.dart';

/// Loads pictures for remote frames. Null when this build has no memory
/// service; frames then hang without a picture.
final remoteMediaLoaderProvider = Provider<RemoteMediaLoader?>((ref) => null);

class RemoteFramesState {
  const RemoteFramesState({
    this.anchors = const <AnchorMemory>[],
    this.loading = false,
    this.failure,
  });

  /// Other people's frames near the viewer, as the service returned them.
  /// Visibility rules (friends, radius) are applied later, by the viewer.
  final List<AnchorMemory> anchors;
  final bool loading;

  /// Why the last query failed, until the next one succeeds. The frames from
  /// the last good query are kept.
  final MemoryApiFailureReason? failure;
}

final remoteFramesProvider =
    NotifierProvider<RemoteFramesController, RemoteFramesState>(
  RemoteFramesController.new,
);

/// Keeps [remoteFramesProvider] fresh while something watches it: asks again
/// when the viewer has moved or the answer is old, and when the user signs in
/// or out. Watch it from whatever shows remote frames.
final remoteFramesAutoRefreshProvider = Provider<void>((ref) {
  void refresh() {
    ref
        .read(remoteFramesProvider.notifier)
        .refreshIfNeeded(ref.read(viewerLocationProvider));
  }

  ref.listen(viewerLocationProvider, (_, __) => refresh());
  ref.listen(currentUserIdProvider, (_, __) => refresh());
  refresh();
});

class RemoteFramesController extends Notifier<RemoteFramesState> {
  /// Ask again after the viewer moved this far.
  static const requeryDistanceMeters = 25.0;

  /// Ask again after this long even if the viewer stood still.
  static const maxAge = Duration(seconds: 60);

  /// How far around the viewer to ask. Wider than the on-site radius so
  /// frames are ready as the viewer walks up to them.
  static const queryRadiusMeters = 100.0;

  /// Pictures fetched per query (nearest first).
  static const maxThumbnailsPerQuery = 8;

  ViewerLocation? _lastLocation;
  DateTime? _lastQueryAt;
  bool _inFlight = false;
  final Map<String, Uint8List> _thumbnails = <String, Uint8List>{};
  List<RemoteFrame> _frames = const <RemoteFrame>[];

  @override
  RemoteFramesState build() {
    // A different user (or none) must never see the last user's frames.
    ref.watch(currentUserIdProvider);
    _lastLocation = null;
    _lastQueryAt = null;
    _inFlight = false;
    _thumbnails.clear();
    _frames = const <RemoteFrame>[];
    return const RemoteFramesState();
  }

  Future<void> refreshIfNeeded(
    ViewerLocation location, {
    DateTime? now,
  }) async {
    final api = ref.read(memoryApiProvider);
    final userId = ref.read(currentUserIdProvider);
    // Only with a real fix (the fallback origin is a development placeholder),
    // a memory service, and a signed-in user.
    if (api == null || userId == null || !location.isLive || _inFlight) {
      return;
    }
    final at = now ?? DateTime.now();
    final lastLocation = _lastLocation;
    final lastQueryAt = _lastQueryAt;
    if (lastLocation != null && lastQueryAt != null) {
      final moved = const AnchorGeoService().distanceBetweenMeters(
        lastLocation.latitude,
        lastLocation.longitude,
        location.latitude,
        location.longitude,
      );
      if (moved < requeryDistanceMeters && at.difference(lastQueryAt) < maxAge) {
        return;
      }
    }

    _inFlight = true;
    _lastLocation = location;
    _lastQueryAt = at;
    state = RemoteFramesState(anchors: state.anchors, loading: true);
    try {
      final frames = await api.nearby(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusMeters: queryRadiusMeters,
        excludeOwnerId: userId,
      );
      if (!_stillCurrent(userId)) {
        return;
      }
      _frames = frames;
      state = RemoteFramesState(anchors: _anchors(at));
      await _loadThumbnails(userId, at);
    } on MemoryApiFailure catch (failure) {
      if (_stillCurrent(userId)) {
        state = RemoteFramesState(
          anchors: state.anchors,
          failure: failure.reason,
        );
      }
    } on Object {
      if (_stillCurrent(userId)) {
        state = RemoteFramesState(
          anchors: state.anchors,
          failure: MemoryApiFailureReason.server,
        );
      }
    } finally {
      _inFlight = false;
    }
  }

  bool _stillCurrent(String userId) {
    return ref.mounted && ref.read(currentUserIdProvider) == userId;
  }

  List<AnchorMemory> _anchors(DateTime now) {
    return List.unmodifiable([
      for (final frame in _frames)
        RemoteFrameMapper.toAnchorMemory(
          frame,
          thumbnailBytes: _thumbnails[frame.id],
          now: now,
        ),
    ]);
  }

  Future<void> _loadThumbnails(String userId, DateTime now) async {
    final loader = ref.read(remoteMediaLoaderProvider);
    if (loader == null) {
      return;
    }
    final wanted = [
      for (final frame in _frames)
        if (frame.thumbnailUrl != null && !_thumbnails.containsKey(frame.id))
          frame,
    ]..sort(
        (a, b) => (a.distanceMeters ?? double.infinity)
            .compareTo(b.distanceMeters ?? double.infinity),
      );
    await Future.wait([
      for (final frame in wanted.take(maxThumbnailsPerQuery))
        () async {
          final bytes = await loader.load(frame.thumbnailUrl!);
          if (bytes == null || !_stillCurrent(userId)) {
            return;
          }
          _thumbnails[frame.id] = bytes;
          state = RemoteFramesState(anchors: _anchors(now));
        }(),
    ]);
  }
}
