/// Chooses which saved memories get a 2D fallback card on top of the camera.
///
/// A memory that is already placed in the native AR scene is drawn by the
/// renderer at its real position, so it must not also get a floating Flutter
/// card: the card ignores the anchor pose and is what made frames look like a
/// flat overlay. Fallback cards exist only for memories the native scene has
/// not placed (no session yet, placement blocked, unsupported device).
///
/// The cap keeps the screen readable; the radar and list still expose every
/// memory.
abstract final class AROverlayAnchorSelector {
  static const int defaultMaxCards = 3;

  /// Returns the items to draw as fallback cards, in draw order: the focused
  /// item first, then the remaining on-screen items nearest first (ties broken
  /// by id so the order is stable between rebuilds).
  ///
  /// Off-screen items are never returned, except the focused one so a
  /// recenter target stays reachable. Items whose id is in [nativelyPlacedIds]
  /// are always excluded.
  static List<T> select<T>(
    Iterable<T> items, {
    required String Function(T item) idOf,
    required double Function(T item) distanceMetersOf,
    required bool Function(T item) isVisibleOf,
    required String? focusedId,
    required Set<String> nativelyPlacedIds,
    int maxCards = defaultMaxCards,
  }) {
    if (maxCards <= 0) {
      return const [];
    }
    final candidates = items
        .where((item) => !nativelyPlacedIds.contains(idOf(item)))
        .where(
          (item) => isVisibleOf(item) || idOf(item) == focusedId,
        )
        .toList()
      ..sort((a, b) {
        final aFocused = idOf(a) == focusedId;
        final bFocused = idOf(b) == focusedId;
        if (aFocused != bFocused) {
          return aFocused ? -1 : 1;
        }
        final byDistance = distanceMetersOf(a).compareTo(distanceMetersOf(b));
        return byDistance != 0 ? byDistance : idOf(a).compareTo(idOf(b));
      });
    return candidates.take(maxCards).toList(growable: false);
  }
}
