import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/parent/models/child_account.dart';
import 'package:jejaku/features/parent/services/sample_parent_service.dart';

final childAccountsProvider =
    NotifierProvider<ChildAccountsController, List<ChildAccount>>(
  ChildAccountsController.new,
);

class ChildAccountsController extends Notifier<List<ChildAccount>> {
  static const extensionDuration = Duration(minutes: 15);

  @override
  List<ChildAccount> build() {
    return const SampleParentService().children();
  }

  void addChild({
    required String name,
    required int age,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    final resolvedAge = age.clamp(4, 17).toInt();
    final child = ChildAccount(
      id: 'child_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmedName,
      age: resolvedAge,
      isOnline: false,
      lastKnownLocation: 'Location not shared yet',
      lastActiveLabel: 'Just added',
      todayScreenTime: Duration.zero,
      hasPendingExtension: false,
      restrictions: resolvedAge < 13
          ? ChildSafetyRestrictions.elementary()
          : ChildSafetyRestrictions.teen(),
      safeZones: const [],
      weeklyStats: const WeeklyStats(
        photosCaptured: 0,
        locationsVisited: 0,
        commentsPosted: 0,
        averageDailyUsage: Duration.zero,
      ),
      blockedContentToday: 0,
    );

    state = [child, ...state];
  }

  void approveExtensionRequest(String childId) {
    state = [
      for (final child in state)
        if (child.id == childId && child.hasPendingExtension)
          child.copyWith(
            hasPendingExtension: false,
            restrictions: child.restrictions.copyWith(
              dailyLimit: child.restrictions.dailyLimit + extensionDuration,
            ),
          )
        else
          child,
    ];
  }

  void denyExtensionRequest(String childId) {
    state = [
      for (final child in state)
        if (child.id == childId && child.hasPendingExtension)
          child.copyWith(hasPendingExtension: false)
        else
          child,
    ];
  }

  void addGeofence({
    required String childId,
    required String name,
    required int radiusMeters,
    required GeoFenceType type,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    final resolvedRadius = radiusMeters.clamp(50, 1000).toInt();
    final zone = GeoFence(
      id: 'zone_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmedName,
      radiusMeters: resolvedRadius,
      type: type,
    );

    state = [
      for (final child in state)
        if (child.id == childId)
          child.copyWith(safeZones: [...child.safeZones, zone])
        else
          child,
    ];
  }
}
