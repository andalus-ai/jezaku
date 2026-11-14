part of '../ar_viewer_screen.dart';

enum _TrailLaunchConflictChoice {
  resumeCurrent,
  replace,
  cancel,
}

enum _ARHudPreset {
  defaultView,
  minimal,
  manual,
}

class ARViewerScreen extends ConsumerStatefulWidget {
  const ARViewerScreen({
    super.key,
    this.focusedMemoryId,
    this.journeyMemoryIds = const [],
    this.journeyTitle,
    this.sourceWallId,
    this.trailSession,
    this.resumeExistingProgress = false,
  });

  final String? focusedMemoryId;
  final List<String> journeyMemoryIds;
  final String? journeyTitle;
  final String? sourceWallId;
  final ARTrailSession? trailSession;
  final bool resumeExistingProgress;

  @override
  ConsumerState<ARViewerScreen> createState() => _ARViewerScreenState();
}
