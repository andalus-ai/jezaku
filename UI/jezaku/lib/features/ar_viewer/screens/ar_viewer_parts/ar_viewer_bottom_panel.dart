part of '../ar_viewer_screen.dart';

/// The bottom action panel, kept out of the (very large) screen state.
extension _ARViewerBottomPanel on _ARViewerScreenState {
  Widget _buildBottomPanel(
    BuildContext context,
    List<ARMemoryProjection> anchors,
    int totalAnchors,
    ARMemoryProjection? focusedAnchor,
    List<ARWall> linkedWalls,
    AnchorJourneyStep? journeyStep,
    String? journeyTitle,
    ARWall? sourceWall,
    List<ARWall> extraWalls,
    Map<String, int> trailStopNumbers,
    AsyncValue<JejakuARCapabilities> arCapabilities,
    AsyncValue<JejakuARSessionPlan> arSessionPlan,
    ARViewerCaptureState arCapture,
    ARMemorySceneDiagnostics sceneDiagnostics,
    ARTrailProgress? trailProgress, {
    required bool showInfoDashboard,
    required bool showRecordingPanel,
  }) {
    final isWallTrail = trailStopNumbers.isNotEmpty;
    final hudAnchors = isWallTrail
        ? anchors
            .where((anchor) => trailStopNumbers.containsKey(anchor.memory.id))
            .toList()
        : anchors;
    final displayTotal = isWallTrail ? hudAnchors.length : totalAnchors;
    final visibleCount = hudAnchors.where((anchor) {
      return anchor.projection.isVisible;
    }).length;
    final reliableCount = hudAnchors.where((anchor) {
      return anchor.projection.assessment.isReliable;
    }).length;
    final reviewCount = hudAnchors.where((anchor) {
      return anchor.memory.needsCalibrationReview;
    }).length;
    final missingTrailAnchor = _firstMissingTrailAnchor(
      trailProgress,
      anchors,
    );
    final sourceWallStopCount = sourceWall?.linkedMemoryIds
        .where((memoryId) => trailStopNumbers.containsKey(memoryId))
        .length;

    final showCaptureControls =
        showRecordingPanel || arCapture.recordingState != ARRecordingState.idle;
    final captureReadinessTrend = ARCaptureReadinessTrend.evaluate(
      sceneDiagnostics,
      arCapture,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showInfoDashboard && focusedAnchor != null) ...[
          _FocusedAnchorPanel(
            anchor: focusedAnchor,
            linkedWalls: linkedWalls,
            onDetails: () => Navigator.pushNamed(
              context,
              AppRoutes.memoryDetails,
              arguments: focusedAnchor.memory.id,
            ),
            onCalibrate: () => Navigator.pushNamed(
              context,
              AppRoutes.memoryCalibration,
              arguments: focusedAnchor.memory.id,
            ),
            onOpenWall: (wall) => Navigator.pushNamed(
              context,
              AppRoutes.virtualWallDetails,
              arguments: wall.id,
            ),
            onRecenter: () => _recenterOnAnchor(focusedAnchor),
          ),
          const SizedBox(height: 12),
        ],
        if (showInfoDashboard &&
            journeyStep != null &&
            journeyStep.total > 1) ...[
          _ARJourneyPanel(
            step: journeyStep,
            title: journeyTitle,
            trailProgress: trailProgress,
            headingDegrees: _headingDegrees,
            sourceWall: sourceWall,
            sourceWallStopCount: sourceWallStopCount,
            extraWalls: extraWalls,
            missingStopMemory: missingTrailAnchor?.memory,
            missingStopSpatialLabel: _missingStopSpatialLabel(
              missingTrailAnchor,
            ),
            onOpenSourceWall: sourceWall == null
                ? null
                : () => Navigator.pushNamed(
                      context,
                      AppRoutes.virtualWallDetails,
                      arguments: sourceWall.id,
                    ),
            onOpenExtraWall: (wall) => Navigator.pushNamed(
              context,
              AppRoutes.virtualWallDetails,
              arguments: wall.id,
            ),
            onPrevious: journeyStep.previousMemory == null
                ? null
                : () => _recenterOnMemoryId(
                      anchors,
                      journeyStep.previousMemory!.id,
                    ),
            onNext: journeyStep.nextMemory == null
                ? null
                : () => _recenterOnMemoryId(
                      anchors,
                      journeyStep.nextMemory!.id,
                    ),
            onOpenMissingStop: missingTrailAnchor == null
                ? null
                : (memoryId) => _recenterOnMemoryId(anchors, memoryId),
            onFinish: _finishTrail,
          ),
          const SizedBox(height: 12),
        ],
        if (showInfoDashboard) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _HudPill(
                key: const ValueKey('ar_pose_source_hud'),
                icon: _poseSourceIcon(),
                label:
                    '${_headingDegrees.round()} deg · ${_poseSourceShortLabel()}',
                color: _poseSourceColor(),
                tooltip: _poseSourceDetailLabel(),
              ),
              _HudPill(
                icon: Icons.photo_camera,
                label: isWallTrail
                    ? '$visibleCount/$displayTotal trail in view'
                    : '$visibleCount/$displayTotal in view',
                color: Colors.greenAccent.shade100,
              ),
              _HudPill(
                icon: Icons.verified,
                label: '$reliableCount reliable',
                color: Colors.amberAccent.shade100,
              ),
              if (sceneDiagnostics.hasSessionHealth)
                _HudPill(
                  key: const ValueKey('ar_session_health_hud'),
                  icon: _sessionHealthIcon(sceneDiagnostics),
                  label: sceneDiagnostics.sessionHealthHudLabel,
                  color: _sessionHealthColor(sceneDiagnostics),
                  tooltip: sceneDiagnostics.sessionHealthDetailLabel,
                ),
              if (reviewCount > 0)
                _HudPill(
                  icon: Icons.warning_amber,
                  label: '$reviewCount review',
                  color: Colors.redAccent.shade100,
                ),
              _HudPill(
                key: const ValueKey('ar_scene_diagnostics_hud'),
                icon: _sceneDiagnosticsIcon(sceneDiagnostics),
                label: sceneDiagnostics.hudStatusLabel,
                color: _sceneDiagnosticsColor(sceneDiagnostics),
                tooltip: sceneDiagnostics.detailStatusLabel,
                onTap: () => _showSceneDiagnosticsSheet(
                  context,
                  sceneDiagnostics,
                  anchors,
                  latestCaptureDiagnostics: ref
                      .read(captureSessionProvider.notifier)
                      .latestArDiagnostics,
                ),
              ),
              ..._capabilityHudPills(arSessionPlan, sceneDiagnostics),
            ],
          ),
          if (showCaptureControls) const SizedBox(height: 12),
        ],
        if (showCaptureControls) ...[
          _ARCaptureControls(
            state: arCapture,
            readinessTrend: captureReadinessTrend,
            onSnapshot: _captureARSnapshot,
            onRecord: _toggleARRecording,
            onPause: _pauseARRecording,
            onResume: _resumeARRecording,
            onCancel: _cancelARRecording,
          ),
        ],
        if (showInfoDashboard) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAnchorSheet(
                    context,
                    _sheetAnchors(anchors),
                    focusedMemoryId: _focusedMemoryId,
                    isWallTrail: _journeyMemoryIds.isNotEmpty,
                  ),
                  icon: const Icon(Icons.list),
                  label: const Text('List'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.camera);
                  },
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Capture'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
