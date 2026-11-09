import 'dart:io';

import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/services/file_anchor_media_repository.dart';

persistentAnchorMediaRepositoryOverride({
  required Directory rootDirectory,
}) {
  return anchorMediaRepositoryProvider.overrideWith((ref) {
    return FileBackedAnchorMediaRepository(
      rootDirectory: rootDirectory,
      onChanged: () {
        ref.read(anchorMediaRepositoryRevisionProvider.notifier).bump();
      },
    );
  });
}

Directory anchorMediaStorageDirectory(Directory appSupportDirectory) {
  return Directory(_joinPath(appSupportDirectory.path, 'anchor_media'));
}

String _joinPath(String parent, String child) {
  if (parent.endsWith(Platform.pathSeparator)) {
    return '$parent$child';
  }
  return '$parent${Platform.pathSeparator}$child';
}
