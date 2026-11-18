/// The rules a display name and handle must follow. Pure, so the edit dialog,
/// the controller and tests all agree on one definition.
class ProfileRules {
  const ProfileRules._();

  static const maxDisplayNameLength = 40;
  static const minHandleLength = 3;
  static const maxHandleLength = 24;

  /// Handles nobody but the team may use, so nobody can pass as official.
  static const reservedHandles = <String>{
    'admin',
    'administrator',
    'jezaku',
    'jejaku',
    'moderator',
    'official',
    'staff',
    'support',
    'system',
  };

  /// `Trail Maker!` becomes `@trail.maker`. Returns an empty string when
  /// nothing usable is left.
  static String normalizeHandle(String value) {
    final trimmed = value.trim().toLowerCase();
    final withoutAt = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    final dotted = withoutAt.replaceAll(RegExp(r'\s+'), '.');
    final cleaned = dotted.replaceAll(RegExp(r'[^a-z0-9._]'), '');
    final collapsed = cleaned.replaceAll(RegExp(r'\.{2,}'), '.');
    final edgeTrimmed = collapsed.replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    if (edgeTrimmed.isEmpty) {
      return '';
    }
    return '@$edgeTrimmed';
  }

  /// Why [value] cannot be a display name, or `null` when it is fine.
  static String? displayNameError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Name required';
    }
    if (trimmed.runes.length > maxDisplayNameLength) {
      return 'Use $maxDisplayNameLength characters or fewer';
    }
    return null;
  }

  /// Why [value] cannot be a handle, or `null` when it is fine. A blank
  /// handle is allowed and means "leave it unchanged".
  static String? handleError(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    final normalized = normalizeHandle(value);
    final body = normalized.isEmpty ? '' : normalized.substring(1);
    if (body.length < minHandleLength || body.length > maxHandleLength) {
      return 'Use $minHandleLength-$maxHandleLength letters, numbers, '
          'dots or underscores';
    }
    if (reservedHandles.contains(body)) {
      return 'That handle is reserved';
    }
    return null;
  }

  static String truncateDisplayName(String value) {
    final runes = value.trim().runes;
    if (runes.length <= maxDisplayNameLength) {
      return value.trim();
    }
    return String.fromCharCodes(runes.take(maxDisplayNameLength)).trim();
  }
}
