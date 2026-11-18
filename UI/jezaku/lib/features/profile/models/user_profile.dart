class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.handle,
  });

  final String displayName;
  final String handle;

  String get initial {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      return '?';
    }
    return String.fromCharCode(trimmedName.runes.first).toUpperCase();
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'displayName': displayName, 'handle': handle};
  }

  /// Returns `null` when the saved data is not a usable profile.
  static UserProfile? tryFromJson(Map<Object?, Object?> json) {
    final name = json['displayName'];
    final handle = json['handle'];
    if (name is! String || handle is! String) {
      return null;
    }
    if (name.trim().isEmpty || handle.trim().isEmpty) {
      return null;
    }
    return UserProfile(displayName: name, handle: handle);
  }

  UserProfile copyWith({
    String? displayName,
    String? handle,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
    );
  }
}
