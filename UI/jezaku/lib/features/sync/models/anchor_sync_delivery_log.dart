import 'package:jejaku/features/sync/models/anchor_sync_payload.dart';

enum AnchorSyncDeliveryStatus {
  delivered('delivered', 'Delivered'),
  deferred('deferred', 'Deferred');

  const AnchorSyncDeliveryStatus(this.wireName, this.label);

  final String wireName;
  final String label;
}

class AnchorSyncDeliveryEntry {
  const AnchorSyncDeliveryEntry({
    required this.id,
    required this.attemptedAt,
    required this.status,
    required this.tenantRealm,
    required this.endpointLabel,
    required this.batchType,
    required this.idempotencyKey,
    required this.payloadFingerprint,
    required this.itemCount,
    required this.mediaCount,
    required this.message,
  });

  final String id;
  final DateTime attemptedAt;
  final AnchorSyncDeliveryStatus status;
  final String tenantRealm;
  final String endpointLabel;
  final AnchorSyncBatchType batchType;
  final String idempotencyKey;
  final String payloadFingerprint;
  final int itemCount;
  final int mediaCount;
  final String message;

  String get statusLabel => status.label;

  String get batchLabel {
    return switch (batchType) {
      AnchorSyncBatchType.fullQueue => 'Full queue',
      AnchorSyncBatchType.uploadMetadata => 'Metadata',
      AnchorSyncBatchType.mediaPayload => 'Media payload',
      AnchorSyncBatchType.singleMemory => 'Single memory',
    };
  }

  String get titleLabel {
    return '${status.label} ${batchLabel.toLowerCase()}';
  }

  String get itemSummaryLabel {
    final itemLabel = itemCount == 1 ? 'sync item' : 'sync items';
    final mediaLabel = mediaCount == 1 ? 'media payload' : 'media payloads';
    return '$itemCount $itemLabel, $mediaCount $mediaLabel';
  }

  String get shortIdempotencyKey {
    if (idempotencyKey.length <= 34) {
      return idempotencyKey;
    }
    return '${idempotencyKey.substring(0, 31)}...';
  }

  String get attemptedAtLabel {
    final local = attemptedAt.toLocal();
    return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }
}

AnchorSyncDeliveryStatus anchorSyncDeliveryStatusFromWireName(
  Object? value, {
  AnchorSyncDeliveryStatus fallback = AnchorSyncDeliveryStatus.deferred,
}) {
  if (value is! String) {
    return fallback;
  }
  for (final status in AnchorSyncDeliveryStatus.values) {
    if (status.wireName == value || status.name == value) {
      return status;
    }
  }
  return fallback;
}

AnchorSyncBatchType anchorSyncBatchTypeFromWireName(
  Object? value, {
  AnchorSyncBatchType fallback = AnchorSyncBatchType.fullQueue,
}) {
  if (value is! String) {
    return fallback;
  }
  for (final type in AnchorSyncBatchType.values) {
    if (type.wireName == value || type.name == value) {
      return type;
    }
  }
  return fallback;
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
