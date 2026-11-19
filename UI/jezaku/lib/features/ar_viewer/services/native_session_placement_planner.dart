import 'package:ar_engine/ar_engine.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_scene_sync_service.dart';
import 'package:jejaku/features/ar_viewer/services/hanging_frame_pose.dart';

/// What the planner needs to know about one memory, without tying it to
/// memory or projection models.
class PlacementCandidate {
  const PlacementCandidate({
    required this.memoryId,
    required this.isInFront,
    required this.relativeHeadingDegrees,
    required this.relativePitchDegrees,
    required this.distanceMeters,
    required this.horizontalDistanceMeters,
    this.capturedThisSession = false,
  });

  final String memoryId;
  final bool isInFront;
  final double relativeHeadingDegrees;
  final double relativePitchDegrees;
  final double distanceMeters;
  final double horizontalDistanceMeters;

  /// True when the memory already has a pose from this AR session, so it must
  /// not get a hanging-frame placement on top of it.
  final bool capturedThisSession;
}

/// Gives memories without a real anchor a stable "hanging photo frame"
/// placement in front of the camera, and remembers it for the session so the
/// frame does not follow the user around.
class NativeSessionPlacementPlanner {
  NativeSessionPlacementPlanner({DateTime Function()? now})
      : _now = now ?? (() => DateTime.now().toUtc());

  /// Camera frames older than this no longer describe where the user is.
  static const Duration maxCameraFrameAge = Duration(seconds: 2);
  static const double maxHeadingDegrees = 72;
  static const double maxPitchDegrees = 22;
  static const double minRenderDistanceMeters = 1.35;
  static const double maxRenderDistanceMeters = 8;
  static const double fallbackRenderDistanceMeters = 1.8;

  final DateTime Function() _now;
  final Map<String, ARMemorySessionPlacement> _cache =
      <String, ARMemorySessionPlacement>{};

  Map<String, ARMemorySessionPlacement> get placements =>
      Map<String, ARMemorySessionPlacement>.unmodifiable(_cache);

  void clear() => _cache.clear();

  void forget(String memoryId) => _cache.remove(memoryId);

  /// Updates and returns the placements for [candidates]. Memories that left
  /// the candidate list are dropped; new ones are placed only while the camera
  /// is tracking and its latest frame is recent.
  Map<String, ARMemorySessionPlacement> plan(
    Iterable<PlacementCandidate> candidates, {
    required ARCamera? camera,
    required DateTime? lastFrameAt,
    required String? focusedMemoryId,
  }) {
    final list = List<PlacementCandidate>.of(candidates);
    final activeIds = {for (final candidate in list) candidate.memoryId};
    _cache.removeWhere((memoryId, _) => !activeIds.contains(memoryId));

    if (camera == null ||
        !camera.isTracking ||
        lastFrameAt == null ||
        _now().difference(lastFrameAt) > maxCameraFrameAge) {
      return placements;
    }

    for (final candidate in list) {
      final id = candidate.memoryId;
      if (candidate.capturedThisSession) {
        _cache.remove(id);
        continue;
      }
      if (_cache.containsKey(id)) {
        continue;
      }
      final isFocused = id == focusedMemoryId;
      if (!candidate.isInFront && !isFocused) {
        continue;
      }

      final heading = (isFocused && !candidate.isInFront)
          ? 0.0
          : candidate.relativeHeadingDegrees
              .clamp(-maxHeadingDegrees, maxHeadingDegrees)
              .toDouble();
      final pitch = candidate.relativePitchDegrees
          .clamp(-maxPitchDegrees, maxPitchDegrees)
          .toDouble();
      final distance = candidate.distanceMeters.isFinite
          ? candidate.distanceMeters
          : candidate.horizontalDistanceMeters;
      final renderDistance = distance.isFinite
          ? distance
              .clamp(minRenderDistanceMeters, maxRenderDistanceMeters)
              .toDouble()
          : fallbackRenderDistanceMeters;

      _cache[id] = ARMemorySessionPlacement(
        anchorPose: HangingFramePose.anchorPose(
          camera,
          HangingFramePose.cameraRelativePosition(
            headingDegrees: heading,
            pitchDegrees: pitch,
            distanceMeters: renderDistance,
          ),
        ),
        nodePosition: const ARVector3.zero(),
        mode: 'hanging_photo_frame',
      );
    }
    return placements;
  }
}

/// Picks the memories to render natively: the focused one first, then every
/// pinned one (up to [pinnedLimit]), then others in view until [limit] items
/// are selected.
///
/// Pinned items have a pose that is valid in the current AR session, so they
/// are kept whatever the GPS-based "in front" test says; otherwise GPS jitter
/// would make a frame the user just hung vanish.
List<T> selectNativeSceneItems<T>(
  List<T> items, {
  required String Function(T item) idOf,
  required bool Function(T item) isInFront,
  required String? focusedId,
  bool Function(T item)? isPinned,
  int limit = 3,
  int pinnedLimit = 8,
}) {
  if (items.isEmpty) {
    return List<T>.unmodifiable(const []);
  }
  final selected = <T>[];
  bool isSelected(T item) => selected.any((c) => idOf(c) == idOf(item));
  if (focusedId != null) {
    for (final item in items) {
      if (idOf(item) == focusedId) {
        selected.add(item);
        break;
      }
    }
  }
  if (isPinned != null) {
    for (final item in items) {
      if (selected.length >= pinnedLimit) {
        break;
      }
      if (!isSelected(item) && isPinned(item)) {
        selected.add(item);
      }
    }
  }
  for (final item in items) {
    if (selected.length >= limit) {
      break;
    }
    if (isSelected(item)) {
      continue;
    }
    if (isInFront(item) || selected.isEmpty) {
      selected.add(item);
    }
  }
  return List<T>.unmodifiable(selected);
}
