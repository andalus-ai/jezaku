class ChildAccount {
  const ChildAccount({
    required this.id,
    required this.name,
    required this.age,
    required this.isOnline,
    required this.lastKnownLocation,
    required this.lastActiveLabel,
    required this.todayScreenTime,
    required this.hasPendingExtension,
    required this.restrictions,
    required this.safeZones,
    required this.weeklyStats,
    required this.blockedContentToday,
  });

  final String id;
  final String name;
  final int age;
  final bool isOnline;
  final String lastKnownLocation;
  final String lastActiveLabel;
  final Duration todayScreenTime;
  final bool hasPendingExtension;
  final ChildSafetyRestrictions restrictions;
  final List<GeoFence> safeZones;
  final WeeklyStats weeklyStats;
  final int blockedContentToday;

  ChildAccount copyWith({
    String? id,
    String? name,
    int? age,
    bool? isOnline,
    String? lastKnownLocation,
    String? lastActiveLabel,
    Duration? todayScreenTime,
    bool? hasPendingExtension,
    ChildSafetyRestrictions? restrictions,
    List<GeoFence>? safeZones,
    WeeklyStats? weeklyStats,
    int? blockedContentToday,
  }) {
    return ChildAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      isOnline: isOnline ?? this.isOnline,
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      lastActiveLabel: lastActiveLabel ?? this.lastActiveLabel,
      todayScreenTime: todayScreenTime ?? this.todayScreenTime,
      hasPendingExtension: hasPendingExtension ?? this.hasPendingExtension,
      restrictions: restrictions ?? this.restrictions,
      safeZones: safeZones ?? this.safeZones,
      weeklyStats: weeklyStats ?? this.weeklyStats,
      blockedContentToday: blockedContentToday ?? this.blockedContentToday,
    );
  }
}

class ChildSafetyRestrictions {
  const ChildSafetyRestrictions({
    required this.blockInappropriate,
    required this.blockStrangers,
    required this.requireFriendApproval,
    required this.hidePreciseLocation,
    required this.dailyLimit,
  });

  final bool blockInappropriate;
  final bool blockStrangers;
  final bool requireFriendApproval;
  final bool hidePreciseLocation;
  final Duration dailyLimit;

  ChildSafetyRestrictions copyWith({
    bool? blockInappropriate,
    bool? blockStrangers,
    bool? requireFriendApproval,
    bool? hidePreciseLocation,
    Duration? dailyLimit,
  }) {
    return ChildSafetyRestrictions(
      blockInappropriate: blockInappropriate ?? this.blockInappropriate,
      blockStrangers: blockStrangers ?? this.blockStrangers,
      requireFriendApproval:
          requireFriendApproval ?? this.requireFriendApproval,
      hidePreciseLocation: hidePreciseLocation ?? this.hidePreciseLocation,
      dailyLimit: dailyLimit ?? this.dailyLimit,
    );
  }

  factory ChildSafetyRestrictions.elementary() {
    return const ChildSafetyRestrictions(
      blockInappropriate: true,
      blockStrangers: true,
      requireFriendApproval: true,
      hidePreciseLocation: true,
      dailyLimit: Duration(minutes: 45),
    );
  }

  factory ChildSafetyRestrictions.teen() {
    return const ChildSafetyRestrictions(
      blockInappropriate: true,
      blockStrangers: false,
      requireFriendApproval: true,
      hidePreciseLocation: false,
      dailyLimit: Duration(minutes: 90),
    );
  }
}

class GeoFence {
  const GeoFence({
    required this.id,
    required this.name,
    required this.radiusMeters,
    required this.type,
  });

  final String id;
  final String name;
  final int radiusMeters;
  final GeoFenceType type;
}

enum GeoFenceType { safe, alert }

class WeeklyStats {
  const WeeklyStats({
    required this.photosCaptured,
    required this.locationsVisited,
    required this.commentsPosted,
    required this.averageDailyUsage,
  });

  final int photosCaptured;
  final int locationsVisited;
  final int commentsPosted;
  final Duration averageDailyUsage;
}
