/// How far one frame got on its way to the server. Each step is saved as soon
/// as it succeeds, so a retry after a dropped connection never uploads the
/// photo twice or creates the frame twice.
enum OutboxStage {
  /// Nothing has reached the server yet.
  queued,

  /// The photo is uploaded ([OutboxEntry.mediaId] is set); the frame is not.
  mediaUploaded,

  /// The frame exists on the server ([OutboxEntry.serverMemoryId] is set).
  published,
}

/// Why a frame is not published yet. The first group is temporary and retried
/// by itself; the second needs the user.
enum OutboxHold {
  /// The device had no usable connection or the service did not answer.
  offline(retries: true),

  /// The service had a problem; trying again later may work.
  serverBusy(retries: true),

  /// The photo is uploaded but the service has not approved it yet, which a
  /// public frame needs before it can be shown.
  awaitingReview(retries: true),

  /// There is no signed-in user, or the service no longer accepts the session.
  signInRequired(retries: false),

  /// The service refused the frame or its photo; sending it again unchanged
  /// will not help.
  rejected(retries: false),

  /// This kind of frame cannot be uploaded yet (for example a recording).
  unsupported(retries: false);

  const OutboxHold({required this.retries});

  /// Whether the outbox tries again on its own after a delay.
  final bool retries;
}

/// One frame waiting to be sent, kept on the device until it is published.
class OutboxEntry {
  const OutboxEntry({
    required this.memoryId,
    required this.queuedAt,
    this.stage = OutboxStage.queued,
    this.mediaId,
    this.serverMemoryId,
    this.attempts = 0,
    this.hold,
    this.nextAttemptAt,
  });

  factory OutboxEntry.fromJson(Map<String, Object?> json) {
    final memoryId = json['memoryId'];
    final queuedAt = DateTime.tryParse('${json['queuedAt']}');
    if (memoryId is! String || memoryId.isEmpty || queuedAt == null) {
      throw const FormatException('Outbox entry needs memoryId and queuedAt');
    }
    return OutboxEntry(
      memoryId: memoryId,
      queuedAt: queuedAt,
      stage: _byName(OutboxStage.values, json['stage']) ?? OutboxStage.queued,
      mediaId: _text(json['mediaId']),
      serverMemoryId: _text(json['serverMemoryId']),
      attempts: json['attempts'] is int ? json['attempts']! as int : 0,
      hold: _byName(OutboxHold.values, json['hold']),
      nextAttemptAt: DateTime.tryParse('${json['nextAttemptAt']}'),
    );
  }

  /// The id of the frame on this device.
  final String memoryId;

  final DateTime queuedAt;
  final OutboxStage stage;

  /// The uploaded photo's id once [stage] reaches [OutboxStage.mediaUploaded].
  final String? mediaId;

  /// The frame's id on the server once it is [OutboxStage.published].
  final String? serverMemoryId;

  /// How many sends have failed since the last success.
  final int attempts;

  /// Why the frame is waiting, or null when nothing is wrong.
  final OutboxHold? hold;

  /// Not before this time, for a held entry that retries by itself.
  final DateTime? nextAttemptAt;

  bool get isPublished => stage == OutboxStage.published;

  /// Whether the outbox may try this entry at [now].
  bool isDue(DateTime now) {
    if (isPublished) {
      return false;
    }
    final blocked = hold;
    if (blocked != null && !blocked.retries) {
      return false;
    }
    final next = nextAttemptAt;
    return next == null || !next.isAfter(now);
  }

  OutboxEntry copyWith({
    OutboxStage? stage,
    String? mediaId,
    String? serverMemoryId,
    int? attempts,
    OutboxHold? hold,
    DateTime? nextAttemptAt,
    bool clearHold = false,
  }) {
    return OutboxEntry(
      memoryId: memoryId,
      queuedAt: queuedAt,
      stage: stage ?? this.stage,
      mediaId: mediaId ?? this.mediaId,
      serverMemoryId: serverMemoryId ?? this.serverMemoryId,
      attempts: attempts ?? this.attempts,
      hold: clearHold ? null : hold ?? this.hold,
      nextAttemptAt: clearHold ? null : nextAttemptAt ?? this.nextAttemptAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'memoryId': memoryId,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
        'stage': stage.name,
        if (mediaId != null) 'mediaId': mediaId,
        if (serverMemoryId != null) 'serverMemoryId': serverMemoryId,
        'attempts': attempts,
        if (hold != null) 'hold': hold!.name,
        if (nextAttemptAt != null)
          'nextAttemptAt': nextAttemptAt!.toUtc().toIso8601String(),
      };

  static String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}
