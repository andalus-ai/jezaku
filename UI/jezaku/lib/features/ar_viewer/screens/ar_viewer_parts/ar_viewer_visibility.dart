part of '../ar_viewer_screen.dart';

/// Applies the central frame visibility policy to the projected frames.
///
/// Everything the viewer draws or counts comes from the returned list. The
/// eligible list (who may see a frame, wherever they stand) is kept only for
/// guidance toward a trail stop, and is never drawn.
extension _ARViewerVisibility on _ARViewerScreenState {
  List<ARMemoryProjection> _applyFrameVisibility(
    List<ARMemoryProjection> projected,
  ) {
    final policy = ref.watch(frameVisibilityPolicyProvider);
    final viewer = ref.watch(frameViewerContextProvider);
    _frameVisibility = policy.resolve(
      projected,
      viewer,
      previouslyViewableIds: _frameVisibility.viewableIds,
    );
    return _frameVisibility.viewable;
  }

  /// Who may see a frame wherever they stand; guidance only, never drawn.
  List<ARMemoryProjection> get _eligibleAnchors => _frameVisibility.eligible;

  List<ARMemoryProjection> _activeProjectedAnchors(
    List<ARMemoryProjection> anchors,
    Map<String, int> trailStopNumbers,
  ) {
    if (trailStopNumbers.isEmpty) {
      final active = anchors.take(8).toList(growable: true);
      final focusedMemoryId = _focusedMemoryId;
      if (focusedMemoryId != null &&
          !active.any((anchor) => anchor.memory.id == focusedMemoryId)) {
        for (final anchor in anchors) {
          if (anchor.memory.id == focusedMemoryId) {
            active.add(anchor);
            break;
          }
        }
      }
      return active;
    }

    final anchorsById = <String, ARMemoryProjection>{
      for (final anchor in anchors) anchor.memory.id: anchor,
    };

    return [
      for (final memoryId in _journeyMemoryIds)
        if (anchorsById[memoryId] != null) anchorsById[memoryId]!,
    ];
  }
}
