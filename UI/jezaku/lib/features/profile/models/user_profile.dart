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
