import 'dart:io';
import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/services/file_anchor_media_repository.dart';

void main() {
  test('stores snapshot bytes with stable ids and defensive copies', () {
    final repository = InMemoryAnchorMediaRepository();
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    final storedAt = DateTime(2026, 5, 30, 12);

    final attachment = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: bytes,
      ),
      storedAt: storedAt,
    );
    bytes[0] = 9;

    expect(attachment.mediaId, 'media_arSnapshot_0001');
    expect(attachment.storagePath, 'jejaku://media/media_arSnapshot_0001');
    expect(attachment.storedAt, storedAt);
    expect(attachment.isStored, isTrue);
    expect(attachment.bytes?.toList(), [1, 2, 3]);

    final storedMedia = repository.mediaById(attachment.mediaId!);
    expect(storedMedia?.type, AnchorMediaType.arSnapshot);
    expect(storedMedia?.byteLength, 3);
    expect(storedMedia?.bytes?.toList(), [1, 2, 3]);

    final returnedBytes = storedMedia!.bytes!;
    returnedBytes[1] = 8;
    expect(storedMedia.bytes?.toList(), [1, 2, 3]);
  });

  test('stores recording metadata and preserves supplied media ids', () {
    final repository = InMemoryAnchorMediaRepository();
    final storedAt = DateTime(2026, 5, 30, 13);
    final qualityReviewedAt = DateTime.utc(2026, 5, 30, 13, 5);
    final arDiagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 5, 30, 13, 4),
      source: 'repository_test',
      hudStatusLabel: 'Native placement ready',
    ).toMap();

    final attachment = repository.storeAttachment(
      AnchorMediaAttachment(
        mediaId: 'existing_recording',
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/clip.mp4',
        duration: const Duration(milliseconds: 1250),
        frameCount: 38,
        targetFps: 30,
        videoBitrateKbps: 6000,
        outputFormat: 'mp4',
        includesUIOverlay: true,
        includesAudio: false,
        fileSizeBytes: 2048,
        recordingQualityReviewedAt: qualityReviewedAt,
        arDiagnostics: arDiagnostics,
      ),
      storedAt: storedAt,
    );

    expect(attachment.mediaId, 'existing_recording');
    expect(attachment.storagePath, 'jejaku://media/existing_recording');
    expect(attachment.filePath, '/tmp/clip.mp4');
    expect(attachment.detailLabel, '1.3 s - 38 frames');
    expect(attachment.recordingMetadataLabels, [
      '30 fps target',
      '30.4 fps captured',
      '6.0 Mbps',
      'MP4',
      'AR visual overlay',
      'Silent',
      'Reviewed 20:05',
      '2.0 KB',
      'AR diagnostics attached',
    ]);
    expect(repository.allMedia, hasLength(1));

    final duplicate = repository.storeAttachment(attachment);

    expect(duplicate.mediaId, 'existing_recording');
    expect(repository.allMedia, hasLength(1));
    expect(repository.mediaById('existing_recording')?.hasSourceFile, isTrue);
    expect(repository.mediaById('existing_recording')?.targetFps, 30);
    expect(repository.mediaById('existing_recording')?.videoBitrateKbps, 6000);
    expect(repository.mediaById('existing_recording')?.outputFormat, 'mp4');
    expect(repository.mediaById('existing_recording')?.fileSizeBytes, 2048);
    expect(
      repository.mediaById('existing_recording')?.recordingQualityReviewedAt,
      qualityReviewedAt,
    );
    expect(
      repository.mediaById('existing_recording')?.arDiagnostics,
      containsPair('schemaVersion', ARCaptureDiagnostics.currentSchemaVersion),
    );
    expect(
      repository.mediaById('existing_recording')?.arDiagnostics,
      containsPair('hudStatusLabel', 'Native placement ready'),
    );
  });

  test('marks stored recording quality reviews in memory cache', () {
    final repository = InMemoryAnchorMediaRepository();
    final attachment = repository.storeAttachment(
      const AnchorMediaAttachment(
        mediaId: 'reviewable_recording',
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/reviewable_clip.mp4',
        duration: Duration(seconds: 1),
        frameCount: 3,
        targetFps: 30,
      ),
    );
    final reviewedAt = DateTime.utc(2026, 5, 30, 12, 10);

    expect(attachment.recordingQualityReviewLabel, 'Quality review pending');
    expect(
      repository.markRecordingQualityReviewed(
        attachment.mediaId!,
        reviewedAt,
      ),
      isTrue,
    );
    expect(
      repository
          .mediaById(attachment.mediaId!)
          ?.toAttachment()
          .recordingQualityReviewLabel,
      'Quality review accepted',
    );
    expect(
      repository.mediaById(attachment.mediaId!)?.recordingQualityReviewedAt,
      reviewedAt,
    );
    expect(
      repository.markRecordingQualityReviewed('missing_recording', reviewedAt),
      isFalse,
    );
  });

  test('media repositories drop unsyncable AR diagnostics from cache', () {
    final inMemoryRepository = InMemoryAnchorMediaRepository();
    final inMemoryAttachment = inMemoryRepository.storeAttachment(
      const AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        arDiagnostics: <String, Object?>{
          'hudStatusLabel': 'Missing capture timestamp',
        },
      ),
    );

    expect(inMemoryAttachment.hasArDiagnostics, isFalse);
    expect(
      inMemoryRepository.mediaById(inMemoryAttachment.mediaId!)?.arDiagnostics,
      isNull,
    );

    final rootDirectory = Directory.systemTemp.createTempSync(
      'jejaku_invalid_ar_diagnostics_cache_',
    );
    addTearDown(() {
      if (rootDirectory.existsSync()) {
        rootDirectory.deleteSync(recursive: true);
      }
    });
    final fileRepository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );
    final fileAttachment = fileRepository.storeAttachment(
      const AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        arDiagnostics: <String, Object?>{
          'hudStatusLabel': 'Missing capture timestamp',
        },
      ),
    );

    final reloadedRepository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );

    expect(fileAttachment.hasArDiagnostics, isFalse);
    expect(
      reloadedRepository.mediaById(fileAttachment.mediaId!)?.arDiagnostics,
      isNull,
    );
  });

  test('removes media and clears cached bytes without reusing sequence ids',
      () {
    final repository = InMemoryAnchorMediaRepository();

    final first = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[1, 2]),
      ),
    );
    final second = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.cameraPhoto,
        bytes: Uint8List.fromList(<int>[3, 4, 5]),
      ),
    );

    expect(repository.cachedMediaCount, 2);
    expect(repository.cachedByteLength, 5);

    expect(repository.removeMedia(first.mediaId!), isTrue);
    expect(repository.removeMedia('missing_media'), isFalse);
    expect(repository.mediaById(first.mediaId!), isNull);
    expect(repository.mediaById(second.mediaId!), isNotNull);
    expect(repository.cachedMediaCount, 1);
    expect(repository.cachedByteLength, 3);

    expect(repository.clearCachedMedia(), 1);
    expect(repository.clearCachedMedia(), 0);
    expect(repository.allMedia, isEmpty);
    expect(repository.cachedByteLength, 0);

    final third = repository.storeAttachment(
      const AnchorMediaAttachment(type: AnchorMediaType.cameraPhoto),
    );

    expect(third.mediaId, 'media_cameraPhoto_0003');

    final report = repository.inspectStorage();
    expect(report.backendLabel, 'In-memory media cache');
    expect(report.cachedMediaCount, 1);
    expect(report.cachedByteLength, 0);
    expect(report.hasStorageWarnings, isFalse);
    expect(report.statusLabel, 'Storage healthy');
    expect(report.issueLabels, isEmpty);
    expect(report.toJson(), {
      'schemaVersion': 1,
      'backendLabel': 'In-memory media cache',
      'cachedMediaCount': 1,
      'cachedByteLength': 0,
      'trackedBlobFileCount': 0,
      'orphanedBlobFileCount': 0,
      'hasPersistentManifest': false,
      'hasBackupManifest': false,
      'hasTemporaryManifest': false,
      'hasInvalidManifest': false,
      'hasStorageWarnings': false,
      'statusLabel': 'Storage healthy',
      'issueLabels': <String>[],
    });

    final repairResult = repository.repairStorage();
    expect(repairResult.repairedAny, isFalse);
    expect(repairResult.summaryLabel, 'Media storage already healthy.');
    expect(repairResult.actionLabels, isEmpty);
  });

  test('file-backed repository reloads stored media after recreation', () {
    final rootDirectory = Directory.systemTemp.createTempSync(
      'jejaku_file_media_repository_',
    );
    addTearDown(() {
      if (rootDirectory.existsSync()) {
        rootDirectory.deleteSync(recursive: true);
      }
    });

    final storedAt = DateTime.utc(2026, 5, 30, 12);
    final qualityReviewedAt = DateTime.utc(2026, 5, 30, 12, 15);
    final arDiagnostics = ARCaptureDiagnostics(
      capturedAt: DateTime.utc(2026, 5, 30, 12, 14),
      source: 'file_repository_test',
      hudStatusLabel: 'Scene pending',
      unsupportedSessionFeatureKeys: const <String>['cloudAnchors'],
    ).toMap();
    final firstRepository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );
    final snapshot = firstRepository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      ),
      storedAt: storedAt,
    );
    final recording = firstRepository.storeAttachment(
      AnchorMediaAttachment(
        mediaId: 'recording_existing',
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/persistent_clip.mp4',
        duration: const Duration(milliseconds: 1500),
        frameCount: 45,
        targetFps: 30,
        videoBitrateKbps: 6000,
        outputFormat: 'mp4',
        includesUIOverlay: true,
        includesAudio: false,
        fileSizeBytes: 4096,
        recordingQualityReviewedAt: qualityReviewedAt,
        arDiagnostics: arDiagnostics,
      ),
    );

    final reloadedRepository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );
    final updatedReviewedAt = DateTime.utc(2026, 5, 30, 12, 30);

    expect(reloadedRepository.cachedMediaCount, 2);
    expect(reloadedRepository.cachedByteLength, 4);
    expect(
      reloadedRepository.mediaById(snapshot.mediaId!)?.bytes?.toList(),
      [1, 2, 3, 4],
    );
    expect(reloadedRepository.mediaById(snapshot.mediaId!)?.storedAt, storedAt);
    expect(
      reloadedRepository.mediaById(recording.mediaId!)?.duration,
      const Duration(milliseconds: 1500),
    );
    expect(reloadedRepository.mediaById(recording.mediaId!)?.frameCount, 45);
    expect(reloadedRepository.mediaById(recording.mediaId!)?.targetFps, 30);
    expect(
      reloadedRepository.mediaById(recording.mediaId!)?.videoBitrateKbps,
      6000,
    );
    expect(
      reloadedRepository.mediaById(recording.mediaId!)?.outputFormat,
      'mp4',
    );
    expect(
      reloadedRepository.mediaById(recording.mediaId!)?.fileSizeBytes,
      4096,
    );
    expect(
      reloadedRepository
          .mediaById(recording.mediaId!)
          ?.recordingQualityReviewedAt,
      qualityReviewedAt,
    );
    expect(
      reloadedRepository.mediaById(recording.mediaId!)?.sourceFilePath,
      '/tmp/persistent_clip.mp4',
    );
    expect(
      reloadedRepository.mediaById(recording.mediaId!)?.arDiagnostics,
      containsPair('source', 'file_repository_test'),
    );
    expect(
      reloadedRepository
          .mediaById(recording.mediaId!)
          ?.arDiagnostics?['unsupportedSessionFeatureKeys'],
      ['cloudAnchors'],
    );
    expect(
      reloadedRepository.markRecordingQualityReviewed(
        recording.mediaId!,
        updatedReviewedAt,
      ),
      isTrue,
    );
    expect(
      FileBackedAnchorMediaRepository(rootDirectory: rootDirectory)
          .mediaById(recording.mediaId!)
          ?.recordingQualityReviewedAt,
      updatedReviewedAt,
    );

    final next = reloadedRepository.storeAttachment(
      const AnchorMediaAttachment(type: AnchorMediaType.cameraPhoto),
    );

    expect(next.mediaId, 'media_cameraPhoto_0002');
  });

  test('file-backed repository persists remove and clear operations', () {
    final rootDirectory = Directory.systemTemp.createTempSync(
      'jejaku_file_media_repository_cleanup_',
    );
    addTearDown(() {
      if (rootDirectory.existsSync()) {
        rootDirectory.deleteSync(recursive: true);
      }
    });

    final repository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );
    final first = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[1, 2]),
      ),
    );
    final second = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.cameraPhoto,
        bytes: Uint8List.fromList(<int>[3, 4, 5]),
      ),
    );

    expect(repository.removeMedia(first.mediaId!), isTrue);

    final afterRemove = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );
    expect(afterRemove.mediaById(first.mediaId!), isNull);
    expect(afterRemove.mediaById(second.mediaId!), isNotNull);
    expect(afterRemove.cachedByteLength, 3);

    expect(afterRemove.clearCachedMedia(), 1);

    final afterClear = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );
    expect(afterClear.allMedia, isEmpty);
    expect(afterClear.cachedByteLength, 0);
  });

  test(
      'file-backed repository restores backup manifests after interrupted saves',
      () {
    final rootDirectory = Directory.systemTemp.createTempSync(
      'jejaku_file_media_repository_backup_',
    );
    addTearDown(() {
      if (rootDirectory.existsSync()) {
        rootDirectory.deleteSync(recursive: true);
      }
    });

    final repository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );
    final snapshot = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[4, 5, 6]),
      ),
    );
    final manifestFile = File(_joinPath(rootDirectory.path, 'media.json'));
    final temporaryManifestFile = File(
      _joinPath(rootDirectory.path, 'media.tmp.json'),
    );
    final backupManifestFile = File(
      _joinPath(rootDirectory.path, 'media.backup.json'),
    );

    expect(temporaryManifestFile.existsSync(), isFalse);
    expect(backupManifestFile.existsSync(), isFalse);

    manifestFile.renameSync(backupManifestFile.path);

    final restoredRepository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );

    expect(manifestFile.existsSync(), isTrue);
    expect(backupManifestFile.existsSync(), isFalse);
    expect(
      restoredRepository.mediaById(snapshot.mediaId!)?.bytes?.toList(),
      [4, 5, 6],
    );

    final next = restoredRepository.storeAttachment(
      const AnchorMediaAttachment(type: AnchorMediaType.cameraPhoto),
    );

    expect(next.mediaId, 'media_cameraPhoto_0002');
    expect(temporaryManifestFile.existsSync(), isFalse);
    expect(backupManifestFile.existsSync(), isFalse);
  });

  test('file-backed repository prunes orphan blobs and stale temp manifests',
      () {
    final rootDirectory = Directory.systemTemp.createTempSync(
      'jejaku_file_media_repository_prune_',
    );
    addTearDown(() {
      if (rootDirectory.existsSync()) {
        rootDirectory.deleteSync(recursive: true);
      }
    });

    final repository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );
    final attachment = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[11, 12, 13]),
      ),
    );
    final blobDirectory = Directory(_joinPath(rootDirectory.path, 'blobs'));
    final orphanBlobFile = File(_joinPath(blobDirectory.path, 'orphan.bin'));
    final temporaryManifestFile = File(
      _joinPath(rootDirectory.path, 'media.tmp.json'),
    );
    orphanBlobFile.writeAsBytesSync(<int>[99], flush: true);
    temporaryManifestFile.writeAsStringSync('partial manifest', flush: true);

    final reloadedRepository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );

    expect(orphanBlobFile.existsSync(), isFalse);
    expect(temporaryManifestFile.existsSync(), isFalse);
    expect(
      reloadedRepository.mediaById(attachment.mediaId!)?.bytes?.toList(),
      [11, 12, 13],
    );
  });

  test('file-backed repository reports storage diagnostics', () {
    final rootDirectory = Directory.systemTemp.createTempSync(
      'jejaku_file_media_repository_diagnostics_',
    );
    addTearDown(() {
      if (rootDirectory.existsSync()) {
        rootDirectory.deleteSync(recursive: true);
      }
    });

    final repository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );
    repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.cameraPhoto,
        bytes: Uint8List.fromList(<int>[21, 22]),
      ),
    );
    final manifestFile = File(_joinPath(rootDirectory.path, 'media.json'));
    final blobDirectory = Directory(_joinPath(rootDirectory.path, 'blobs'));
    final orphanBlobFile = File(_joinPath(blobDirectory.path, 'orphan.bin'));
    final backupManifestFile = File(
      _joinPath(rootDirectory.path, 'media.backup.json'),
    );
    final temporaryManifestFile = File(
      _joinPath(rootDirectory.path, 'media.tmp.json'),
    );
    final invalidManifestFile = File(
      _joinPath(rootDirectory.path, 'media.invalid.json'),
    );
    orphanBlobFile.writeAsBytesSync(<int>[99], flush: true);
    backupManifestFile.writeAsBytesSync(
      manifestFile.readAsBytesSync(),
      flush: true,
    );
    temporaryManifestFile.writeAsStringSync('pending manifest', flush: true);
    invalidManifestFile.writeAsStringSync('bad manifest', flush: true);

    final report = repository.inspectStorage();

    expect(report.backendLabel, 'File-backed media cache');
    expect(report.cachedMediaCount, 1);
    expect(report.cachedByteLength, 2);
    expect(report.trackedBlobFileCount, 1);
    expect(report.orphanedBlobFileCount, 1);
    expect(report.hasPersistentManifest, isTrue);
    expect(report.hasBackupManifest, isTrue);
    expect(report.hasTemporaryManifest, isTrue);
    expect(report.hasInvalidManifest, isTrue);
    expect(report.hasStorageWarnings, isTrue);
    expect(report.issueLabels, [
      '1 orphaned media file',
      'temporary manifest pending',
      'backup manifest available',
      'recovery manifest available',
    ]);
    expect(
      report.statusLabel,
      '1 orphaned media file, temporary manifest pending, '
      'backup manifest available, recovery manifest available',
    );
    expect(report.toJson(), {
      'schemaVersion': 1,
      'backendLabel': 'File-backed media cache',
      'cachedMediaCount': 1,
      'cachedByteLength': 2,
      'trackedBlobFileCount': 1,
      'orphanedBlobFileCount': 1,
      'hasPersistentManifest': true,
      'hasBackupManifest': true,
      'hasTemporaryManifest': true,
      'hasInvalidManifest': true,
      'hasStorageWarnings': true,
      'statusLabel': '1 orphaned media file, temporary manifest pending, '
          'backup manifest available, recovery manifest available',
      'issueLabels': <String>[
        '1 orphaned media file',
        'temporary manifest pending',
        'backup manifest available',
        'recovery manifest available',
      ],
    });
  });

  test('file-backed repository repairs storage diagnostics warnings', () {
    final rootDirectory = Directory.systemTemp.createTempSync(
      'jejaku_file_media_repository_repair_',
    );
    addTearDown(() {
      if (rootDirectory.existsSync()) {
        rootDirectory.deleteSync(recursive: true);
      }
    });

    final repository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );
    final attachment = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.cameraPhoto,
        bytes: Uint8List.fromList(<int>[31, 32]),
      ),
    );
    final manifestFile = File(_joinPath(rootDirectory.path, 'media.json'));
    final blobDirectory = Directory(_joinPath(rootDirectory.path, 'blobs'));
    final orphanBlobFile = File(_joinPath(blobDirectory.path, 'orphan.bin'));
    final backupManifestFile = File(
      _joinPath(rootDirectory.path, 'media.backup.json'),
    );
    final temporaryManifestFile = File(
      _joinPath(rootDirectory.path, 'media.tmp.json'),
    );
    final invalidManifestFile = File(
      _joinPath(rootDirectory.path, 'media.invalid.json'),
    );
    orphanBlobFile.writeAsBytesSync(<int>[99], flush: true);
    backupManifestFile.writeAsBytesSync(
      manifestFile.readAsBytesSync(),
      flush: true,
    );
    temporaryManifestFile.writeAsStringSync('pending manifest', flush: true);
    invalidManifestFile.writeAsStringSync('bad manifest', flush: true);

    final result = repository.repairStorage();

    expect(result.repairedAny, isTrue);
    expect(result.removedOrphanedBlobFileCount, 1);
    expect(result.removedTemporaryManifest, isTrue);
    expect(result.removedBackupManifest, isTrue);
    expect(result.removedInvalidManifest, isTrue);
    expect(result.restoredBackupManifest, isFalse);
    expect(result.rebuiltManifest, isFalse);
    expect(result.actionLabels, [
      'removed 1 orphaned media file',
      'cleared temporary manifest',
      'cleared backup manifest',
      'cleared recovery manifest',
    ]);
    expect(
      result.summaryLabel,
      'removed 1 orphaned media file, cleared temporary manifest, '
      'cleared backup manifest, cleared recovery manifest',
    );
    expect(result.toJson(), {
      'schemaVersion': 1,
      'removedOrphanedBlobFileCount': 1,
      'removedTemporaryManifest': true,
      'removedBackupManifest': true,
      'removedInvalidManifest': true,
      'restoredBackupManifest': false,
      'rebuiltManifest': false,
      'repairedAny': true,
      'summaryLabel': 'removed 1 orphaned media file, '
          'cleared temporary manifest, cleared backup manifest, '
          'cleared recovery manifest',
      'actionLabels': <String>[
        'removed 1 orphaned media file',
        'cleared temporary manifest',
        'cleared backup manifest',
        'cleared recovery manifest',
      ],
    });
    expect(orphanBlobFile.existsSync(), isFalse);
    expect(temporaryManifestFile.existsSync(), isFalse);
    expect(backupManifestFile.existsSync(), isFalse);
    expect(invalidManifestFile.existsSync(), isFalse);
    expect(repository.inspectStorage().hasStorageWarnings, isFalse);
    expect(
      repository.mediaById(attachment.mediaId!)?.bytes?.toList(),
      [31, 32],
    );
  });

  test('file-backed repository recovers from invalid manifests', () {
    final rootDirectory = Directory.systemTemp.createTempSync(
      'jejaku_file_media_repository_recovery_',
    );
    addTearDown(() {
      if (rootDirectory.existsSync()) {
        rootDirectory.deleteSync(recursive: true);
      }
    });

    rootDirectory.createSync(recursive: true);
    final manifestFile = File(_joinPath(rootDirectory.path, 'media.json'));
    final invalidManifestFile = File(
      _joinPath(rootDirectory.path, 'media.invalid.json'),
    );
    manifestFile.writeAsStringSync('{not valid json', flush: true);

    final repository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );

    expect(repository.allMedia, isEmpty);
    expect(manifestFile.existsSync(), isFalse);
    expect(invalidManifestFile.readAsStringSync(), '{not valid json');

    final attachment = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[7, 8]),
      ),
    );

    expect(attachment.mediaId, 'media_arSnapshot_0001');
    expect(manifestFile.existsSync(), isTrue);

    final reloadedRepository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );

    expect(
      reloadedRepository.mediaById(attachment.mediaId!)?.bytes?.toList(),
      [7, 8],
    );
  });

  test(
      'file-backed repository prefers a backup over an invalid active manifest',
      () {
    final rootDirectory = Directory.systemTemp.createTempSync(
      'jejaku_file_media_repository_invalid_with_backup_',
    );
    addTearDown(() {
      if (rootDirectory.existsSync()) {
        rootDirectory.deleteSync(recursive: true);
      }
    });

    final repository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );
    final attachment = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.cameraPhoto,
        bytes: Uint8List.fromList(<int>[9, 10]),
      ),
    );
    final manifestFile = File(_joinPath(rootDirectory.path, 'media.json'));
    final backupManifestFile = File(
      _joinPath(rootDirectory.path, 'media.backup.json'),
    );
    final invalidManifestFile = File(
      _joinPath(rootDirectory.path, 'media.invalid.json'),
    );
    backupManifestFile.writeAsBytesSync(
      manifestFile.readAsBytesSync(),
      flush: true,
    );
    manifestFile.writeAsStringSync('{not valid json', flush: true);

    final recoveredRepository = FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
    );

    expect(
      recoveredRepository.mediaById(attachment.mediaId!)?.bytes?.toList(),
      [9, 10],
    );
    expect(manifestFile.existsSync(), isTrue);
    expect(backupManifestFile.existsSync(), isFalse);
    expect(invalidManifestFile.readAsStringSync(), '{not valid json');
  });
}

String _joinPath(String parent, String child) {
  if (parent.endsWith(Platform.pathSeparator)) {
    return '$parent$child';
  }
  return '$parent${Platform.pathSeparator}$child';
}
