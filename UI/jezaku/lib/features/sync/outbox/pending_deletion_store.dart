import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A frame the owner deleted on this device that the memory service may still
/// hold. It is kept until the service has been told, so a frame deleted while
/// offline (or when the app is closed before the call) does not come back.
class PendingDeletion {
  const PendingDeletion({
    required this.serverMemoryId,
    required this.deletedAt,
    this.ownerId,
  });

  factory PendingDeletion.fromJson(Map<String, Object?> json) {
    final id = json['serverMemoryId'];
    final at = DateTime.tryParse('${json['deletedAt']}');
    if (id is! String || id.isEmpty || at == null) {
      throw const FormatException('Not a pending deletion');
    }
    final owner = json['ownerId'];
    return PendingDeletion(
      serverMemoryId: id,
      deletedAt: at,
      ownerId: owner is String && owner.isNotEmpty ? owner : null,
    );
  }

  /// The frame's id on the memory service.
  final String serverMemoryId;

  /// Who deleted it. Only that user's session may send the deletion; null
  /// (an owner that was never recorded) lets any signed-in user send it.
  final String? ownerId;

  final DateTime deletedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'serverMemoryId': serverMemoryId,
        'deletedAt': deletedAt.toUtc().toIso8601String(),
        if (ownerId != null) 'ownerId': ownerId,
      };
}

/// Where deletions waiting for the service are kept.
abstract class PendingDeletionStore {
  List<PendingDeletion> load();

  Future<void> save(List<PendingDeletion> deletions);
}

class InMemoryPendingDeletionStore implements PendingDeletionStore {
  List<PendingDeletion> _deletions = const <PendingDeletion>[];

  @override
  List<PendingDeletion> load() => _deletions;

  @override
  Future<void> save(List<PendingDeletion> deletions) async {
    _deletions = List<PendingDeletion>.unmodifiable(deletions);
  }
}

const _deletionsKey = 'jejaku.frame_deletions.v1';

class SharedPreferencesPendingDeletionStore implements PendingDeletionStore {
  const SharedPreferencesPendingDeletionStore({
    required SharedPreferences preferences,
    String key = _deletionsKey,
  })  : _preferences = preferences,
        _key = key;

  final SharedPreferences _preferences;
  final String _key;

  /// Records that cannot be read are skipped one by one: one damaged record
  /// must not hide the other waiting deletions.
  @override
  List<PendingDeletion> load() {
    final encoded = _preferences.getString(_key);
    if (encoded == null || encoded.trim().isEmpty) {
      return const <PendingDeletion>[];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return const <PendingDeletion>[];
    }
    if (decoded is! List) {
      return const <PendingDeletion>[];
    }
    final deletions = <PendingDeletion>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      try {
        deletions.add(PendingDeletion.fromJson(Map<String, Object?>.from(item)));
      } on FormatException {
        continue;
      }
    }
    return List<PendingDeletion>.unmodifiable(deletions);
  }

  @override
  Future<void> save(List<PendingDeletion> deletions) async {
    await _preferences.setString(
      _key,
      jsonEncode(deletions.map((d) => d.toJson()).toList()),
    );
  }
}
