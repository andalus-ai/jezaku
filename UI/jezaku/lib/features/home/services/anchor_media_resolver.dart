import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';

final anchorResolvedMediaProvider =
    Provider.family<AnchorResolvedMedia?, AnchorMemory>((ref, memory) {
  final attachment = memory.mediaAttachment;
  if (attachment == null) {
    return null;
  }

  ref.watch(anchorMediaRepositoryRevisionProvider);
  final repository = ref.watch(anchorMediaRepositoryProvider);
  AnchorStoredMedia? storedMedia;
  final mediaId = attachment.mediaId?.trim();
  if (mediaId != null && mediaId.isNotEmpty) {
    storedMedia = repository.mediaById(mediaId);
  }

  return AnchorResolvedMedia(
    attachment: attachment,
    storedMedia: storedMedia,
  );
});

class AnchorResolvedMedia {
  const AnchorResolvedMedia({
    required this.attachment,
    this.storedMedia,
  });

  final AnchorMediaAttachment attachment;
  final AnchorStoredMedia? storedMedia;

  AnchorMediaType get type => attachment.type;

  Uint8List? get previewBytes {
    if (!canPreviewAsImage) {
      return null;
    }
    return attachment.bytes ?? storedMedia?.bytes;
  }

  bool get canPreviewAsImage {
    return attachment.type != AnchorMediaType.arRecording &&
        attachment.type != AnchorMediaType.arModel;
  }

  String? get mediaId {
    final attachmentId = attachment.mediaId?.trim();
    if (attachmentId != null && attachmentId.isNotEmpty) {
      return attachmentId;
    }
    return storedMedia?.id;
  }

  String? get storagePath {
    final attachmentPath = attachment.storagePath?.trim();
    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      return attachmentPath;
    }
    return storedMedia?.storagePath;
  }

  int? get storedByteLength {
    final byteLength = storedMedia?.byteLength;
    if (byteLength == null || byteLength <= 0) {
      return null;
    }
    return byteLength;
  }

  bool get hasStoredReference => mediaId != null;

  bool get hasRepositoryRecord => storedMedia != null;

  bool get hasCachedPreview => previewBytes != null;

  bool get isPreviewCacheMissing {
    return canPreviewAsImage &&
        hasStoredReference &&
        attachment.bytes == null &&
        storedMedia == null;
  }

  String get availabilityLabel {
    if (!canPreviewAsImage) {
      if (attachment.type == AnchorMediaType.arModel) {
        if (hasRepositoryRecord || hasStoredReference) {
          return '3D object reference stored';
        }
        return '3D object pending';
      }
      if (hasRepositoryRecord || hasStoredReference) {
        return 'Screen recording reference stored';
      }
      return 'Screen recording pending';
    }
    if (hasCachedPreview) {
      return 'Preview cached';
    }
    if (isPreviewCacheMissing) {
      return 'Preview cache missing';
    }
    if (hasRepositoryRecord || hasStoredReference) {
      return 'Preview pending';
    }
    return 'Media pending';
  }
}
