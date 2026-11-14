import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';

final viewerLocationSourceProvider = Provider<ViewerLocationSource>((ref) {
  return const UnavailableViewerLocationSource();
});

/// The viewer's current origin. Starts at [ViewerLocation.fallback] and moves
/// to live fixes as the [ViewerLocationSource] emits them.
final viewerLocationProvider =
    NotifierProvider<ViewerLocationController, ViewerLocation>(
  ViewerLocationController.new,
);

class ViewerLocationController extends Notifier<ViewerLocation> {
  /// Ignore live fixes that moved less than this, to avoid rebuild churn.
  static const minimumMoveMeters = 5.0;

  @override
  ViewerLocation build() {
    final subscription = ref.watch(viewerLocationSourceProvider).watch().listen(
          update,
          onError: (Object _) {},
        );
    ref.onDispose(subscription.cancel);
    return ViewerLocation.fallback;
  }

  void update(ViewerLocation location) {
    if (!ref.mounted) {
      return;
    }
    final current = state;
    if (current.isLive && location.isLive) {
      final movedMeters = const AnchorGeoService().distanceBetweenMeters(
        current.latitude,
        current.longitude,
        location.latitude,
        location.longitude,
      );
      if (movedMeters < minimumMoveMeters) {
        return;
      }
    }
    state = location;
  }
}
