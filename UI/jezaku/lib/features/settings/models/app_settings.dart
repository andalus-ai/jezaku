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

  /// What gets persisted. [cachedMediaMb] is left out on purpose: it is a
  /// measurement of the cache, not a preference.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'nearbyNotifications': nearbyNotifications,
      'privateByDefault': privateByDefault,
      'highAccuracyMode': highAccuracyMode,
      'familyLocationAlerts': familyLocationAlerts,
      'weeklyGuardianDigest': weeklyGuardianDigest,
      'approvalReminders': approvalReminders,
      'sharePreciseLocation': sharePreciseLocation,
      'commentsEnabledByDefault': commentsEnabledByDefault,
      'profileDiscoverable': profileDiscoverable,
      'blockedAccounts': blockedAccounts,
    };
  }

  /// Reads persisted settings, taking [fallback] for any key that is missing
  /// or has the wrong type, so adding a setting later never discards the rest.
  factory AppSettings.fromJson(
    Map<Object?, Object?> json, {
    required AppSettings fallback,
  }) {
    bool flag(String key, bool fallbackValue) {
      final value = json[key];
      return value is bool ? value : fallbackValue;
    }

    final rawBlocked = json['blockedAccounts'];
    final blocked = rawBlocked is List
        ? <String>[
            for (final entry in rawBlocked)
              if (entry is String && entry.trim().isNotEmpty) entry.trim(),
          ]
        : fallback.blockedAccounts;

    return AppSettings(
      nearbyNotifications:
          flag('nearbyNotifications', fallback.nearbyNotifications),
      privateByDefault: flag('privateByDefault', fallback.privateByDefault),
      highAccuracyMode: flag('highAccuracyMode', fallback.highAccuracyMode),
      familyLocationAlerts:
          flag('familyLocationAlerts', fallback.familyLocationAlerts),
      weeklyGuardianDigest:
          flag('weeklyGuardianDigest', fallback.weeklyGuardianDigest),
      approvalReminders: flag('approvalReminders', fallback.approvalReminders),
      cachedMediaMb: fallback.cachedMediaMb,
      sharePreciseLocation:
          flag('sharePreciseLocation', fallback.sharePreciseLocation),
      commentsEnabledByDefault:
          flag('commentsEnabledByDefault', fallback.commentsEnabledByDefault),
      profileDiscoverable:
          flag('profileDiscoverable', fallback.profileDiscoverable),
      blockedAccounts: List.unmodifiable(blocked),
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
