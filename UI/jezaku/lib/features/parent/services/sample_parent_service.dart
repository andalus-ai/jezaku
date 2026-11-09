import 'package:jejaku/features/parent/models/child_account.dart';

class SampleParentService {
  const SampleParentService();

  List<ChildAccount> children() {
    return [
      ChildAccount(
        id: 'anna',
        name: 'Anna',
        age: 10,
        isOnline: true,
        lastKnownLocation: 'Home - 123 Main Street',
        lastActiveLabel: '5 min ago',
        todayScreenTime: const Duration(minutes: 37),
        hasPendingExtension: true,
        restrictions: ChildSafetyRestrictions.elementary(),
        safeZones: const [
          GeoFence(
            id: 'home',
            name: 'Home',
            radiusMeters: 120,
            type: GeoFenceType.safe,
          ),
          GeoFence(
            id: 'school',
            name: 'School',
            radiusMeters: 220,
            type: GeoFenceType.safe,
          ),
        ],
        weeklyStats: const WeeklyStats(
          photosCaptured: 12,
          locationsVisited: 8,
          commentsPosted: 5,
          averageDailyUsage: Duration(minutes: 42),
        ),
        blockedContentToday: 3,
      ),
      ChildAccount(
        id: 'james',
        name: 'James',
        age: 14,
        isOnline: false,
        lastKnownLocation: 'School - Park Avenue',
        lastActiveLabel: '2 hours ago',
        todayScreenTime: const Duration(minutes: 85),
        hasPendingExtension: false,
        restrictions: ChildSafetyRestrictions.teen(),
        safeZones: const [
          GeoFence(
            id: 'home',
            name: 'Home',
            radiusMeters: 120,
            type: GeoFenceType.safe,
          ),
          GeoFence(
            id: 'mall',
            name: 'Mall alert zone',
            radiusMeters: 300,
            type: GeoFenceType.alert,
          ),
        ],
        weeklyStats: const WeeklyStats(
          photosCaptured: 25,
          locationsVisited: 15,
          commentsPosted: 18,
          averageDailyUsage: Duration(minutes: 75),
        ),
        blockedContentToday: 0,
      ),
    ];
  }
}
