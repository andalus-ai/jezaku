class AppSettings {
  const AppSettings({
    required this.nearbyNotifications,
    required this.privateByDefault,
    required this.highAccuracyMode,
    required this.familyLocationAlerts,
    required this.weeklyGuardianDigest,
    required this.approvalReminders,
    required this.cachedMediaMb,
    required this.sharePreciseLocation,
    required this.commentsEnabledByDefault,
    required this.profileDiscoverable,
    required this.blockedAccounts,
  });

  final bool nearbyNotifications;
  final bool privateByDefault;
  final bool highAccuracyMode;
  final bool familyLocationAlerts;
  final bool weeklyGuardianDigest;
  final bool approvalReminders;
  final int cachedMediaMb;
  final bool sharePreciseLocation;
  final bool commentsEnabledByDefault;
  final bool profileDiscoverable;
  final List<String> blockedAccounts;

  String get privacySafetySummary {
    final locationLabel = sharePreciseLocation
        ? 'Precise location on'
        : 'Approximate location only';
    final commentsLabel =
        commentsEnabledByDefault ? 'Comments on' : 'Comments off';
    return '$locationLabel - $commentsLabel - $blockedAccountsLabel';
  }

  String get blockedAccountsLabel {
    return '${blockedAccounts.length} blocked account'
        '${blockedAccounts.length == 1 ? '' : 's'}';
  }

  bool isAccountBlocked(String accountName) {
    final normalizedName = accountName.trim().toLowerCase();
    return blockedAccounts.any(
      (account) => account.trim().toLowerCase() == normalizedName,
    );
  }

  AppSettings copyWith({
    bool? nearbyNotifications,
    bool? privateByDefault,
    bool? highAccuracyMode,
    bool? familyLocationAlerts,
    bool? weeklyGuardianDigest,
    bool? approvalReminders,
    int? cachedMediaMb,
    bool? sharePreciseLocation,
    bool? commentsEnabledByDefault,
    bool? profileDiscoverable,
    List<String>? blockedAccounts,
  }) {
    return AppSettings(
      nearbyNotifications: nearbyNotifications ?? this.nearbyNotifications,
      privateByDefault: privateByDefault ?? this.privateByDefault,
      highAccuracyMode: highAccuracyMode ?? this.highAccuracyMode,
      familyLocationAlerts: familyLocationAlerts ?? this.familyLocationAlerts,
      weeklyGuardianDigest: weeklyGuardianDigest ?? this.weeklyGuardianDigest,
      approvalReminders: approvalReminders ?? this.approvalReminders,
      cachedMediaMb: cachedMediaMb ?? this.cachedMediaMb,
      sharePreciseLocation: sharePreciseLocation ?? this.sharePreciseLocation,
      commentsEnabledByDefault:
          commentsEnabledByDefault ?? this.commentsEnabledByDefault,
      profileDiscoverable: profileDiscoverable ?? this.profileDiscoverable,
      blockedAccounts: blockedAccounts ?? this.blockedAccounts,
    );
  }
}
