import 'package:flutter/material.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';

void showARTrailCompletionSnackBar({
  required ScaffoldMessengerState messenger,
  required List<ARTrailAchievementUnlock> unlocks,
  required bool isSaved,
  required VoidCallback? onSave,
}) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          unlocks.isEmpty
              ? 'Trail completed.'
              : formatARTrailAchievementUnlocks(unlocks),
        ),
        action: isSaved || onSave == null
            ? null
            : SnackBarAction(
                label: 'Save trail',
                onPressed: onSave,
              ),
      ),
    );
}

void showARTrailSavedSnackBar({
  required ScaffoldMessengerState messenger,
  required List<ARTrailAchievementUnlock> unlocks,
  required VoidCallback? onReplay,
}) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trail saved.'),
            if (unlocks.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(formatARTrailAchievementUnlocks(unlocks)),
            ],
          ],
        ),
        action: onReplay == null
            ? null
            : SnackBarAction(
                label: 'Replay',
                onPressed: onReplay,
              ),
      ),
    );
}
