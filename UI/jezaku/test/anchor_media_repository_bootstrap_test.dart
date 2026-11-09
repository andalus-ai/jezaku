import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/services/anchor_media_repository_bootstrap.dart';
import 'package:jejaku/features/home/services/file_anchor_media_repository.dart';

void main() {
  test('persistent override stores and reloads file-backed media', () {
    final rootDirectory = Directory.systemTemp.createTempSync(
      'jejaku_media_bootstrap_',
    );
    addTearDown(() {
      if (rootDirectory.existsSync()) {
        rootDirectory.deleteSync(recursive: true);
      }
    });

    final firstContainer = ProviderContainer(
      overrides: [
        persistentAnchorMediaRepositoryOverride(
          rootDirectory: rootDirectory,
        ),
      ],
    );
    late AnchorMediaAttachment storedAttachment;
    try {
      final repository = firstContainer.read(anchorMediaRepositoryProvider);
      final initialRevision = firstContainer.read(
        anchorMediaRepositoryRevisionProvider,
      );

      expect(repository, isA<FileBackedAnchorMediaRepository>());

      storedAttachment = repository.storeAttachment(
        AnchorMediaAttachment(
          type: AnchorMediaType.arSnapshot,
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
        storedAt: DateTime.utc(2026, 5, 30, 12),
      );

      expect(
        firstContainer.read(anchorMediaRepositoryRevisionProvider),
        initialRevision + 1,
      );
    } finally {
      firstContainer.dispose();
    }

    final reloadedContainer = ProviderContainer(
      overrides: [
        persistentAnchorMediaRepositoryOverride(
          rootDirectory: rootDirectory,
        ),
      ],
    );
    addTearDown(reloadedContainer.dispose);

    final reloadedRepository = reloadedContainer.read(
      anchorMediaRepositoryProvider,
    );

    expect(reloadedRepository, isA<FileBackedAnchorMediaRepository>());
    expect(
      reloadedRepository.mediaById(storedAttachment.mediaId!)?.bytes?.toList(),
      [1, 2, 3],
    );
  });

  test('anchor media storage directory nests below app support', () {
    final appSupportDirectory = Directory(
      _joinPath(Directory.systemTemp.path, 'jejaku_support'),
    );

    final mediaDirectory = anchorMediaStorageDirectory(appSupportDirectory);

    expect(
      mediaDirectory.path,
      _joinPath(appSupportDirectory.path, 'anchor_media'),
    );
  });
}

String _joinPath(String parent, String child) {
  if (parent.endsWith(Platform.pathSeparator)) {
    return '$parent$child';
  }
  return '$parent${Platform.pathSeparator}$child';
}
