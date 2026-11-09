import 'package:jejaku/features/home/models/anchor_memory.dart';

class AnchorMediaSyncManifest {
  const AnchorMediaSyncManifest({
    required this.type,
    required this.summaryLabel,
    required this.isStored,
    required this.requiresUpload,
    required this.byteLength,
    required this.hasSourceFile,
    this.uploadStatus = AnchorMediaUploadStatus.queued,
    this.retryCount = 0,
    this.errorMessage,
    this.mediaId,
    this.storagePath,
    this.modelPath,
    this.modelFormat,
    this.modelSource,
    this.modelPackage,
    this.modelValidationIsValid,
    this.modelValidationSummary,
    this.modelValidationIssueLabels = const <String>[],
    this.modelValidationErrorLabels = const <String>[],
    this.modelValidationWarningLabels = const <String>[],
    this.modelUsesAndroidPrimitiveFallback = false,
    this.modelRenderProfileSummary,
    this.modelRenderProfileLabels = const <String>[],
    this.modelRenderProfileNotes = const <String>[],
    this.modelAndroidRenderMode,
    this.modelIosRenderMode,
    this.modelUsesAnyPrimitiveFallback = false,
    this.modelRequiresPreparation = false,
  });

  factory AnchorMediaSyncManifest.fromAttachment(
    AnchorMediaAttachment attachment, {
    AnchorMediaUploadEntry? uploadEntry,
  }) {
    final validationReport = attachment.modelValidationReport;
    final renderProfile = attachment.modelRenderProfile;
    return AnchorMediaSyncManifest(
      type: attachment.type,
      summaryLabel: attachment.summaryLabel,
      isStored: attachment.isStored,
      requiresUpload: attachment.hasUploadablePayload,
      byteLength: attachment.bytes?.lengthInBytes ?? 0,
      hasSourceFile: attachment.hasFile,
      uploadStatus: uploadEntry?.status ?? AnchorMediaUploadStatus.queued,
      retryCount: uploadEntry?.retryCount ?? 0,
      errorMessage: uploadEntry?.errorMessage,
      mediaId: attachment.mediaId,
      storagePath: attachment.storagePath,
      modelPath: attachment.modelAsset?.path,
      modelFormat: attachment.modelAsset?.format.name,
      modelSource: attachment.modelAsset?.source.name,
      modelPackage: attachment.modelAsset?.package,
      modelValidationIsValid: validationReport?.isValid,
      modelValidationSummary: validationReport?.summaryLabel,
      modelValidationIssueLabels:
          validationReport?.issueLabels ?? const <String>[],
      modelValidationErrorLabels:
          validationReport?.errorLabels ?? const <String>[],
      modelValidationWarningLabels:
          validationReport?.warningLabels ?? const <String>[],
      modelUsesAndroidPrimitiveFallback:
          validationReport?.usesAndroidPrimitiveFallback ?? false,
      modelRenderProfileSummary: renderProfile?.summaryLabel,
      modelRenderProfileLabels:
          renderProfile?.platformLabels ?? const <String>[],
      modelRenderProfileNotes: renderProfile?.noteLabels ?? const <String>[],
      modelAndroidRenderMode: renderProfile?.android.mode.name,
      modelIosRenderMode: renderProfile?.ios.mode.name,
      modelUsesAnyPrimitiveFallback:
          renderProfile?.usesAnyPrimitiveFallback ?? false,
      modelRequiresPreparation: renderProfile?.requiresPreparation ?? false,
    );
  }

  final AnchorMediaType type;
  final String summaryLabel;
  final bool isStored;
  final bool requiresUpload;
  final int byteLength;
  final bool hasSourceFile;
  final AnchorMediaUploadStatus uploadStatus;
  final int retryCount;
  final String? errorMessage;
  final String? mediaId;
  final String? storagePath;
  final String? modelPath;
  final String? modelFormat;
  final String? modelSource;
  final String? modelPackage;
  final bool? modelValidationIsValid;
  final String? modelValidationSummary;
  final List<String> modelValidationIssueLabels;
  final List<String> modelValidationErrorLabels;
  final List<String> modelValidationWarningLabels;
  final bool modelUsesAndroidPrimitiveFallback;
  final String? modelRenderProfileSummary;
  final List<String> modelRenderProfileLabels;
  final List<String> modelRenderProfileNotes;
  final String? modelAndroidRenderMode;
  final String? modelIosRenderMode;
  final bool modelUsesAnyPrimitiveFallback;
  final bool modelRequiresPreparation;

  String get identityLabel {
    final id = mediaId;
    if (id == null || id.isEmpty) {
      return 'Unstored media';
    }
    return id;
  }

  String get storageLabel {
    final path = storagePath;
    if (path == null || path.isEmpty) {
      return 'Storage pending';
    }
    return path;
  }

  String get statusLabel {
    return isStored ? 'Stored media' : 'Storage pending';
  }

  String get payloadLabel {
    if (byteLength > 0) {
      return '${_formatBytes(byteLength)} payload';
    }
    if (hasSourceFile) {
      return 'File-backed payload';
    }
    if (type == AnchorMediaType.arModel) {
      return requiresUpload ? '3D model file payload' : '3D model metadata';
    }
    return 'Metadata payload';
  }

  String? get modelFormatLabel {
    final format = modelFormat;
    if (format == null || format.isEmpty) {
      return null;
    }
    return '${format.toUpperCase()} model';
  }

  String? get modelSourceLabel {
    final source = modelSource;
    if (source == null || source.isEmpty) {
      return null;
    }
    return switch (source) {
      'flutterAsset' => 'Flutter asset',
      'file' => 'Local model file',
      'network' => 'Network model',
      'bundle' => 'Bundled model',
      _ => source,
    };
  }

  String? get modelPathLabel {
    final path = modelPath;
    if (path == null || path.isEmpty) {
      return null;
    }
    return _basename(path);
  }

  String? get modelPackageLabel {
    final package = modelPackage;
    if (package == null || package.isEmpty) {
      return null;
    }
    return 'Package $package';
  }

  String? get modelValidationLabel {
    final summary = modelValidationSummary;
    if (summary == null || summary.isEmpty) {
      return null;
    }
    return summary;
  }

  String? get modelRenderProfileLabel {
    final summary = modelRenderProfileSummary;
    if (summary == null || summary.isEmpty) {
      return null;
    }
    return summary;
  }

  String get uploadStatusLabel => uploadStatus.label;

  String get retryLabel {
    return '$retryCount ${retryCount == 1 ? 'retry' : 'retries'}';
  }
}

enum AnchorMediaUploadStatus {
  queued('Media queued'),
  uploading('Uploading media'),
  uploaded('Media uploaded'),
  failed('Media failed');

  const AnchorMediaUploadStatus(this.label);

  final String label;
}

class AnchorMediaUploadEntry {
  const AnchorMediaUploadEntry({
    required this.key,
    required this.memoryId,
    required this.status,
    this.mediaId,
    this.retryCount = 0,
    this.updatedAt,
    this.errorMessage,
  });

  factory AnchorMediaUploadEntry.queuedFor(
    AnchorMemory memory, {
    DateTime? updatedAt,
  }) {
    return AnchorMediaUploadEntry(
      key: mediaUploadKeyFor(memory),
      memoryId: memory.id,
      mediaId: memory.mediaAttachment?.mediaId,
      status: AnchorMediaUploadStatus.queued,
      updatedAt: updatedAt,
    );
  }

  final String key;
  final String memoryId;
  final String? mediaId;
  final AnchorMediaUploadStatus status;
  final int retryCount;
  final DateTime? updatedAt;
  final String? errorMessage;

  AnchorMediaUploadEntry copyWith({
    AnchorMediaUploadStatus? status,
    int? retryCount,
    DateTime? updatedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AnchorMediaUploadEntry(
      key: key,
      memoryId: memoryId,
      mediaId: mediaId,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

String mediaUploadKeyFor(AnchorMemory memory) {
  final mediaId = memory.mediaAttachment?.mediaId;
  if (mediaId != null && mediaId.isNotEmpty) {
    return mediaId;
  }
  return 'memory_${memory.id}_media';
}

AnchorMediaUploadEntry mediaUploadEntryFor(
  Map<String, AnchorMediaUploadEntry> entries,
  AnchorMemory memory,
) {
  return entries[mediaUploadKeyFor(memory)] ??
      AnchorMediaUploadEntry.queuedFor(memory);
}

String _formatBytes(int byteCount) {
  if (byteCount < 1024) {
    return '$byteCount B';
  }
  final kib = byteCount / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }
  return '${(kib / 1024).toStringAsFixed(1)} MB';
}

String _basename(String path) {
  final normalized = path.split('?').first;
  final parts = normalized.split(RegExp(r'[/\\]'));
  return parts.isEmpty ? normalized : parts.last;
}
