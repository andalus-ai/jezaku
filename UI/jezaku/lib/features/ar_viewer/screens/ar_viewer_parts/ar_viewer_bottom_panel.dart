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
    final colors = Theme.of(context).colorScheme;
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
      _eligibleAnchors,
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
    final hasTroubleshootingIssue = sceneDiagnostics.hasSessionHealthIssue ||
        sceneDiagnostics.hasRuntimeDiagnosticsIssue ||
        sceneDiagnostics.hasNativeSceneFailure ||
        sceneDiagnostics.hasCloudAnchorFailures ||
        sceneDiagnostics.hasModelPreflightIssues ||
        sceneDiagnostics.hasSessionConfigDowngrades;
    final healthGuidance = sceneDiagnostics.sessionHealthGuidance;
    final troubleshootingTitle = sceneDiagnostics.hasSessionHealthIssue
        ? sceneDiagnostics.sessionHealthStatusLabel
        : sceneDiagnostics.hasRuntimeDiagnosticsIssue
            ? sceneDiagnostics.runtimeDiagnosticsStatusLabel
            : sceneDiagnostics.hasNativeSceneFailure
                ? 'Scene synchronization issue'
                : sceneDiagnostics.hasCloudAnchorFailures
                    ? 'Cloud anchor needs attention'
                    : sceneDiagnostics.hasModelPreflightIssues
                        ? 'Some anchor models need attention'
                        : 'Device capability limitation';
    final troubleshootingMessage =
        healthGuidance?.message ??
        sceneDiagnostics.runtimeDiagnosticsGuidanceLabel ??
        (sceneDiagnostics.hasNativeSceneFailure
            ? sceneDiagnostics.nativeSceneFailureMessage
            : null) ??
        (sceneDiagnostics.hasCloudAnchorFailures
            ? sceneDiagnostics.cloudAnchorStatusLabel
            : null) ??
        (sceneDiagnostics.hasModelPreflightIssues
            ? sceneDiagnostics.modelPreflightStatusLabel
            : null) ??
        (sceneDiagnostics.hasSessionConfigDowngrades
            ? 'This device cannot provide: '
                '${sceneDiagnostics.unsupportedSessionFeatureLabels.join(', ')}. '
                'AR viewing remains available with reduced capabilities.'
            : null) ??
        sceneDiagnostics.sessionHealthDetailLabel;
    final isDeviceLimitation = sceneDiagnostics.hasSessionConfigDowngrades &&
        !sceneDiagnostics.hasSessionHealthIssue &&
        !sceneDiagnostics.hasRuntimeDiagnosticsIssue &&
        !sceneDiagnostics.hasNativeSceneFailure &&
        !sceneDiagnostics.hasCloudAnchorFailures &&
        !sceneDiagnostics.hasModelPreflightIssues;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (anchors.isEmpty && !isWallTrail) ...[
          const FrameRadiusEmptyHint(radiusMeters: defaultFrameViewRadiusMeters),
          const SizedBox(height: 8),
        ],
        if (showInfoDashboard && hasTroubleshootingIssue) ...[
          Material(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const ValueKey('ar_troubleshooting_summary'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showSceneDiagnosticsSheet(
                context,
                sceneDiagnostics,
                anchors,
                latestCaptureDiagnostics: ref
                    .read(captureSessionProvider.notifier)
                    .latestArDiagnostics,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isDeviceLimitation
                          ? Icons.info_outline
                          : Icons.build_circle_outlined,
                      color: isDeviceLimitation
                          ? colors.secondary
                          : colors.tertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            troubleshootingTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            troubleshootingMessage,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isDeviceLimitation
                                ? 'DEVICE LIMITATION · View details'
                                : 'TROUBLESHOOT · View details',
                            style: TextStyle(
                              color: isDeviceLimitation
                                  ? colors.secondary
                                  : colors.tertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (showInfoDashboard && focusedAnchor != null) ...[
          _FocusedAnchorPanel(
            anchor: focusedAnchor,
            linkedWalls: linkedWalls,
            onOpenPhoto: () => Navigator.pushNamed(
              context,
              AppRoutes.memoryPhoto,
              arguments: focusedAnchor.memory.id,
            ),
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
            onRehang: _canOfferRehang(focusedAnchor.memory)
                ? () => _rehangMemory(focusedAnchor.memory)
                : null,
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
                color: _poseSourceColor(colors),
                tooltip: _poseSourceDetailLabel(),
              ),
              _HudPill(
                icon: Icons.photo_camera,
                label: isWallTrail
                    ? '$visibleCount/$displayTotal trail in view'
                    : '$visibleCount/$displayTotal in view',
                color: colors.primary,
              ),
              _HudPill(
                icon: Icons.verified,
                label: '$reliableCount reliable',
                color: colors.tertiary,
              ),
              if (sceneDiagnostics.hasSessionHealth)
                _HudPill(
                  key: const ValueKey('ar_session_health_hud'),
                  icon: _sessionHealthIcon(sceneDiagnostics),
                  label: sceneDiagnostics.sessionHealthHudLabel,
                  color: _sessionHealthColor(sceneDiagnostics, colors),
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
                color: _sceneDiagnosticsColor(sceneDiagnostics, colors),
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
              ..._capabilityHudPills(arSessionPlan, sceneDiagnostics, colors),
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
                  key: const ValueKey('ar_viewer_capture_button'),
                  // Photograph through the running AR session. The separate
                  // camera screen competes with ARCore for the camera, which
                  // leaves AR stale and saves a generated placeholder.
                  onPressed: arCapture.isBusy
                      ? null
                      : () => _captureFromViewer(arCapture),
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
