import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/services/ar_capture_diagnostics_payload.dart';

class FileBackedAnchorMediaRepository implements AnchorMediaRepository {
  FileBackedAnchorMediaRepository({
    required Directory rootDirectory,
    void Function()? onChanged,
  })  : _rootDirectory = rootDirectory,
        _onChanged = onChanged {
    _initialize();
  }

  final Directory _rootDirectory;
  final void Function()? _onChanged;
  final _mediaById = <String, AnchorStoredMedia>{};
  int _nextSequence = 1;

  File get _manifestFile => File(_joinPath(_rootDirectory.path, 'media.json'));

  File get _temporaryManifestFile =>
      File(_joinPath(_rootDirectory.path, 'media.tmp.json'));

  File get _backupManifestFile =>
      File(_joinPath(_rootDirectory.path, 'media.backup.json'));

  File get _invalidManifestFile =>
      File(_joinPath(_rootDirectory.path, 'media.invalid.json'));

  Directory get _blobDirectory =>
      Directory(_joinPath(_rootDirectory.path, 'blobs'));

  @override
  List<AnchorStoredMedia> get allMedia {
    return List<AnchorStoredMedia>.unmodifiable(_mediaById.values);
  }

  @override
  int get cachedByteLength {
    return _mediaById.values.fold<int>(
      0,
      (total, media) => total + media.byteLength,
    );
  }

  @override
  int get cachedMediaCount => _mediaById.length;

  @override
  AnchorStoredMedia? mediaById(String mediaId) {
    return _mediaById[mediaId];
  }

  @override
  bool markRecordingQualityReviewed(String mediaId, DateTime reviewedAt) {
    final normalizedMediaId = mediaId.trim();
    final media = _mediaById[normalizedMediaId];
    if (media == null) {
      return false;
    }

    _mediaById[normalizedMediaId] =
        media.withRecordingQualityReviewedAt(reviewedAt);
    _persist();
    _onChanged?.call();
    return true;
  }

  @override
  AnchorMediaAttachment storeAttachment(
    AnchorMediaAttachment attachment, {
    DateTime? storedAt,
  }) {
    final existingId = attachment.mediaId;
    if (existingId != null && _mediaById.containsKey(existingId)) {
      return _mediaById[existingId]!.toAttachment();
    }

    final mediaId = existingId == null || existingId.trim().isEmpty
        ? _generateMediaId(attachment.type)
        : existingId;
    final resolvedStoredAt = storedAt ?? attachment.storedAt ?? DateTime.now();
    final bytes = attachment.bytes;
    if (bytes != null) {
      _blobFile(mediaId).writeAsBytesSync(bytes, flush: true);
    }

    final storedMedia = AnchorStoredMedia(
      id: mediaId,
      type: attachment.type,
      storagePath: attachment.storagePath ?? 'jejaku://media/$mediaId',
      storedAt: resolvedStoredAt,
      bytes: bytes,
      sourceFilePath: attachment.filePath,
      duration: attachment.duration,
      frameCount: attachment.frameCount,
      targetFps: attachment.targetFps,
      videoBitrateKbps: attachment.videoBitrateKbps,
      outputFormat: attachment.outputFormat,
      includesUIOverlay: attachment.includesUIOverlay,
      includesAudio: attachment.includesAudio,
      fileSizeBytes: attachment.fileSizeBytes,
      recordingQualityReviewedAt: attachment.recordingQualityReviewedAt,
      arDiagnostics: attachment.arDiagnostics,
    );
    _mediaById[mediaId] = storedMedia;
    _persist();
    _onChanged?.call();
    return storedMedia.toAttachment();
  }

  @override
  bool removeMedia(String mediaId) {
    final normalizedMediaId = mediaId.trim();
    final removedMedia = _mediaById.remove(normalizedMediaId);
    if (removedMedia == null) {
      return false;
    }

    final blobFile = _blobFile(normalizedMediaId);
    if (blobFile.existsSync()) {
      blobFile.deleteSync();
    }
    _persist();
    _onChanged?.call();
    return true;
  }

  @override
  int clearCachedMedia() {
    final clearedCount = _mediaById.length;
    if (clearedCount == 0) {
      return 0;
    }

    _mediaById.clear();
    if (_blobDirectory.existsSync()) {
      _blobDirectory.deleteSync(recursive: true);
    }
    _blobDirectory.createSync(recursive: true);
    _persist();
    _onChanged?.call();
    return clearedCount;
  }

  @override
  AnchorMediaStorageReport inspectStorage() {
    final blobFilePaths = _blobFilePaths();
    final referencedBlobPaths = _referencedBlobPaths();
    return AnchorMediaStorageReport(
      backendLabel: 'File-backed media cache',
      cachedMediaCount: cachedMediaCount,
      cachedByteLength: cachedByteLength,
      trackedBlobFileCount: referencedBlobPaths
          .where((blobPath) => blobFilePaths.contains(blobPath))
          .length,
      orphanedBlobFileCount:
          blobFilePaths.difference(referencedBlobPaths).length,
      hasPersistentManifest: _manifestFile.existsSync(),
      hasBackupManifest: _backupManifestFile.existsSync(),
      hasTemporaryManifest: _temporaryManifestFile.existsSync(),
      hasInvalidManifest: _invalidManifestFile.existsSync(),
    );
  }

  @override
  AnchorMediaStorageRepairResult repairStorage() {
    _rootDirectory.createSync(recursive: true);
    _blobDirectory.createSync(recursive: true);

    final removedTemporaryManifest = _deleteExistingFile(
      _temporaryManifestFile,
    );
    var restoredBackupManifest = _restoreBackupManifestIfNeeded();
    var rebuiltManifest = false;

    if (_manifestFile.existsSync() && !_isReadableManifest(_manifestFile)) {
      _recoverFromInvalidManifest();
      restoredBackupManifest =
          _restoreBackupManifestIfNeeded() || restoredBackupManifest;
    }

    if (_manifestFile.existsSync() && _isReadableManifest(_manifestFile)) {
      _loadManifest();
    }

    if (!_manifestFile.existsSync()) {
      _persist();
      rebuiltManifest = true;
    }

    final removedBackupManifest = _manifestFile.existsSync() &&
        _isReadableManifest(_manifestFile) &&
        _deleteExistingFile(_backupManifestFile);
    final removedInvalidManifest = _manifestFile.existsSync() &&
        _isReadableManifest(_manifestFile) &&
        _deleteExistingFile(_invalidManifestFile);
    final removedOrphanedBlobFileCount = _pruneUnreferencedBlobFiles();

    final result = AnchorMediaStorageRepairResult(
      removedOrphanedBlobFileCount: removedOrphanedBlobFileCount,
      removedTemporaryManifest: removedTemporaryManifest,
      removedBackupManifest: removedBackupManifest,
      removedInvalidManifest: removedInvalidManifest,
      restoredBackupManifest: restoredBackupManifest,
      rebuiltManifest: rebuiltManifest,
    );
    if (result.repairedAny) {
      _onChanged?.call();
    }
    return result;
  }

  void _initialize() {
    _rootDirectory.createSync(recursive: true);
    _blobDirectory.createSync(recursive: true);
    _deleteFileIfPresent(_temporaryManifestFile);
    _restoreBackupManifestIfNeeded();
    if (!_manifestFile.existsSync()) {
      _pruneUnreferencedBlobFiles();
      return;
    }

    if (_loadManifest()) {
      _deleteFileIfPresent(_backupManifestFile);
      _pruneUnreferencedBlobFiles();
      return;
    }

    _recoverFromInvalidManifest();
    _restoreBackupManifestIfNeeded();
    if (_manifestFile.existsSync() && _loadManifest()) {
      _deleteFileIfPresent(_backupManifestFile);
      _pruneUnreferencedBlobFiles();
    }
  }

  bool _loadManifest() {
    _mediaById.clear();
    _nextSequence = 1;

    final Object? decoded;
    try {
      decoded = jsonDecode(_manifestFile.readAsStringSync());
    } on FormatException {
      return false;
    } on FileSystemException {
      return false;
    }

    if (decoded is! Map<String, Object?>) {
      return false;
    }

    final manifestNextSequence = decoded['nextSequence'];
    final entries = decoded['media'];
    if (entries is! List) {
      return false;
    }

    for (final entry in entries) {
      AnchorStoredMedia? media;
      try {
        media = _mediaFromJson(entry);
      } on FileSystemException {
        media = null;
      }
      if (media != null) {
        _mediaById[media.id] = media;
      }
    }

    _nextSequence = manifestNextSequence is int && manifestNextSequence > 0
        ? manifestNextSequence
        : _nextSequenceAfter(_mediaById.keys);
    return true;
  }

  void _recoverFromInvalidManifest() {
    _mediaById.clear();
    _nextSequence = 1;
    if (!_manifestFile.existsSync()) {
      return;
    }

    if (!_deleteFileIfPresent(_invalidManifestFile)) {
      return;
    }

    var renamed = false;
    try {
      _manifestFile.renameSync(_invalidManifestFile.path);
      renamed = true;
    } on FileSystemException {
      renamed = false;
    }
    if (renamed) {
      return;
    }

    try {
      _invalidManifestFile.writeAsBytesSync(
        _manifestFile.readAsBytesSync(),
        flush: true,
      );
      _manifestFile.deleteSync();
    } on FileSystemException {
      return;
    }
  }

  bool _restoreBackupManifestIfNeeded() {
    if (_manifestFile.existsSync() || !_backupManifestFile.existsSync()) {
      return false;
    }

    try {
      _moveFile(_backupManifestFile, _manifestFile);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  bool _deleteFileIfPresent(File file) {
    if (!file.existsSync()) {
      return true;
    }

    try {
      file.deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  bool _deleteExistingFile(File file) {
    if (!file.existsSync()) {
      return false;
    }
    return _deleteFileIfPresent(file);
  }

  bool _isReadableManifest(File file) {
    if (!file.existsSync()) {
      return false;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException {
      return false;
    } on FileSystemException {
      return false;
    }

    return decoded is Map<String, Object?> && decoded['media'] is List;
  }

  int _pruneUnreferencedBlobFiles() {
    if (!_blobDirectory.existsSync()) {
      return 0;
    }

    final referencedBlobPaths = _referencedBlobPaths();
    var removedCount = 0;
    for (final entity in _blobDirectory.listSync(followLinks: false)) {
      if (entity is! File || referencedBlobPaths.contains(entity.path)) {
        continue;
      }
      if (_deleteFileIfPresent(entity)) {
        removedCount += 1;
      }
    }
    return removedCount;
  }

  Set<String> _referencedBlobPaths() {
    return {
      for (final media in _mediaById.values)
        if (media.hasBytes) _blobFile(media.id).path,
    };
  }

  Set<String> _blobFilePaths() {
    if (!_blobDirectory.existsSync()) {
      return const {};
    }

    return {
      for (final entity in _blobDirectory.listSync(followLinks: false))
        if (entity is File) entity.path,
    };
  }

  AnchorStoredMedia? _mediaFromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final id = value['id'];
    final typeName = value['type'];
    final storagePath = value['storagePath'];
    final storedAtValue = value['storedAt'];
    if (id is! String ||
        typeName is! String ||
        storagePath is! String ||
        storedAtValue is! String) {
      return null;
    }

    final type = _mediaTypeByName(typeName);
    final storedAt = DateTime.tryParse(storedAtValue);
    if (type == null || storedAt == null) {
      return null;
    }

    final blobFile = _blobFile(id);
    final bytes = blobFile.existsSync()
        ? Uint8List.fromList(blobFile.readAsBytesSync())
        : null;
    final durationMilliseconds = value['durationMilliseconds'];
    final frameCount = value['frameCount'];
    final targetFps = value['targetFps'];
    final videoBitrateKbps = value['videoBitrateKbps'];
    final outputFormat = value['outputFormat'];
    final includesUIOverlay = value['includesUIOverlay'];
    final includesAudio = value['includesAudio'];
    final fileSizeBytes = value['fileSizeBytes'];
    final recordingQualityReviewedAtValue = value['recordingQualityReviewedAt'];
    final sourceFilePath = value['sourceFilePath'];
    final arDiagnostics = value['arDiagnostics'];

    return AnchorStoredMedia(
      id: id,
      type: type,
      storagePath: storagePath,
      storedAt: storedAt,
      bytes: bytes,
      sourceFilePath: sourceFilePath is String ? sourceFilePath : null,
      duration: durationMilliseconds is int
          ? Duration(milliseconds: durationMilliseconds)
          : null,
      frameCount: frameCount is int ? frameCount : null,
      targetFps: targetFps is int ? targetFps : null,
      videoBitrateKbps: videoBitrateKbps is int ? videoBitrateKbps : null,
      outputFormat: outputFormat is String ? outputFormat : null,
      includesUIOverlay: includesUIOverlay is bool ? includesUIOverlay : true,
      includesAudio: includesAudio is bool ? includesAudio : false,
      fileSizeBytes: fileSizeBytes is int ? fileSizeBytes : null,
      recordingQualityReviewedAt: recordingQualityReviewedAtValue is String
          ? DateTime.tryParse(recordingQualityReviewedAtValue)
          : null,
      arDiagnostics: normalizedARCaptureDiagnosticsPayload(arDiagnostics),
    );
  }

  void _persist() {
    _rootDirectory.createSync(recursive: true);
    _blobDirectory.createSync(recursive: true);
    final manifest = <String, Object?>{
      'version': 1,
      'nextSequence': _nextSequence,
      'media': [
        for (final media in _mediaById.values) _mediaToJson(media),
      ],
    };
    _temporaryManifestFile.writeAsStringSync(jsonEncode(manifest), flush: true);
    try {
      _deleteFileIfPresent(_backupManifestFile);
      if (_manifestFile.existsSync()) {
        _moveFile(_manifestFile, _backupManifestFile);
      }
      _moveFile(_temporaryManifestFile, _manifestFile);
      _deleteFileIfPresent(_backupManifestFile);
    } on FileSystemException {
      _restoreBackupManifestIfNeeded();
      rethrow;
    }
  }

  void _moveFile(File source, File destination) {
    try {
      source.renameSync(destination.path);
    } on FileSystemException {
      destination.writeAsBytesSync(source.readAsBytesSync(), flush: true);
      source.deleteSync();
    }
  }

  Map<String, Object?> _mediaToJson(AnchorStoredMedia media) {
    return {
      'id': media.id,
      'type': media.type.name,
      'storagePath': media.storagePath,
      'storedAt': media.storedAt.toUtc().toIso8601String(),
      if (media.hasBytes) 'blobFileName': _blobFileName(media.id),
      if (media.sourceFilePath != null) 'sourceFilePath': media.sourceFilePath,
      if (media.duration != null)
        'durationMilliseconds': media.duration!.inMilliseconds,
      if (media.frameCount != null) 'frameCount': media.frameCount,
      if (media.targetFps != null) 'targetFps': media.targetFps,
      if (media.videoBitrateKbps != null)
        'videoBitrateKbps': media.videoBitrateKbps,
      if (media.outputFormat != null) 'outputFormat': media.outputFormat,
      'includesUIOverlay': media.includesUIOverlay,
      'includesAudio': media.includesAudio,
      if (media.fileSizeBytes != null) 'fileSizeBytes': media.fileSizeBytes,
      if (media.recordingQualityReviewedAt != null)
        'recordingQualityReviewedAt':
            media.recordingQualityReviewedAt!.toUtc().toIso8601String(),
      if (media.arDiagnostics != null)
        'arDiagnostics': normalizedARCaptureDiagnosticsPayload(
          media.arDiagnostics,
        ),
    };
  }

  AnchorMediaType? _mediaTypeByName(String typeName) {
    for (final type in AnchorMediaType.values) {
      if (type.name == typeName) {
        return type;
      }
    }
    return null;
  }

  File _blobFile(String mediaId) {
    return File(_joinPath(_blobDirectory.path, _blobFileName(mediaId)));
  }

  String _blobFileName(String mediaId) {
    return '${Uri.encodeComponent(mediaId)}.bin';
  }

  String _generateMediaId(AnchorMediaType type) {
    final sequence = _nextSequence++;
    return 'media_${type.name}_${sequence.toString().padLeft(4, '0')}';
  }

  int _nextSequenceAfter(Iterable<String> mediaIds) {
    var nextSequence = 1;
    final generatedIdPattern = RegExp(r'^media_[A-Za-z]+_(\d+)$');
    for (final mediaId in mediaIds) {
      final match = generatedIdPattern.firstMatch(mediaId);
      if (match == null) {
        continue;
      }
      final sequence = int.tryParse(match.group(1)!);
      if (sequence != null && sequence >= nextSequence) {
        nextSequence = sequence + 1;
      }
    }
    return nextSequence;
  }

  String _joinPath(String parent, String child) {
    if (parent.endsWith(Platform.pathSeparator)) {
      return '$parent$child';
    }
    return '$parent${Platform.pathSeparator}$child';
  }
}
