part of '../ar_viewer_screen.dart';

/// The scene diagnostics bottom sheet, kept out of the (very large) screen state.
extension _ARViewerSceneDiagnosticsSheet on _ARViewerScreenState {
  void _showSceneDiagnosticsSheet(
    BuildContext context,
    ARMemorySceneDiagnostics diagnostics,
    List<ARMemoryProjection> anchors, {
    ARCaptureDiagnostics? latestCaptureDiagnostics,
  }) {
    final cloudAnchorIssues = diagnostics.cloudAnchorIssuesFor(
      anchors.map((anchor) => anchor.memory),
    );
    final anchorMemoryIds = {
      for (final anchor in anchors) anchor.memory.id,
    };
    final latestCaptureSurfaceLabel = _captureDiagnosticsExtraString(
      latestCaptureDiagnostics,
      'localSurfacePoseLabel',
    );
    final latestCaptureDedicatedLabels = <String?>{
      latestCaptureDiagnostics?.captureCapabilityLabel,
      latestCaptureDiagnostics?.captureReadinessGuidanceLabel,
    };
    final latestCaptureDetailLabels = latestCaptureDiagnostics?.metadataLabels
            .skip(1)
            .where((label) => !latestCaptureDedicatedLabels.contains(label))
            .take(4)
            .toList() ??
        const <String>[];
    final latestCaptureSessionDiagnosticsReport =
        _captureSessionDiagnosticsReport(latestCaptureDiagnostics);
    final latestCaptureSessionDiagnosticsLatestWarning =
        latestCaptureSessionDiagnosticsReport?.latestWarning;
    final sessionDiagnosticsReport = diagnostics.sessionDiagnosticsReport;
    final sessionDiagnosticsReportFacetLabels = sessionDiagnosticsReport
            ?.queryResult
            .facetLabels(limitPerKind: 2)
            .take(3)
            .toList() ??
        const <String>[];
    final sessionDiagnosticsLatestWarning =
        sessionDiagnosticsReport?.latestWarning;
    final sessionDiagnosticsHistoryReports = diagnostics
        .sessionDiagnosticsReportHistory.reversed
        .take(3)
        .toList(growable: false);
    final sessionDiagnosticsLatestDiff =
        _latestSessionDiagnosticsReportDiff(diagnostics);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Native scene diagnostics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close diagnostics',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        _sceneDiagnosticsIcon(diagnostics),
                        size: 16,
                      ),
                      label: Text(diagnostics.hudStatusLabel),
                      backgroundColor: _sceneDiagnosticsColor(diagnostics),
                    ),
                    const SizedBox(height: 8),
                    _DiagnosticsRow(
                      icon: Icons.timeline,
                      label: 'Session',
                      value: diagnostics.sessionStatusLabel,
                    ),
                    _DiagnosticsRow(
                      icon: _sessionHealthIcon(diagnostics),
                      label: 'Tracking',
                      value: diagnostics.sessionHealthStatusLabel,
                      valueColor: diagnostics.hasSessionHealthIssue
                          ? _sessionHealthColor(diagnostics)
                          : null,
                    ),
                    if (diagnostics.sessionReadiness != null)
                      _DiagnosticsRow(
                        icon: Icons.fact_check_outlined,
                        label: 'Readiness',
                        value: diagnostics.sessionReadinessLabel,
                        valueColor: diagnostics.isSessionReadyForPlacement
                            ? null
                            : _sessionHealthColor(diagnostics),
                      ),
                    _DiagnosticsRow(
                      icon: Icons.add_location_alt_outlined,
                      label: 'Placement',
                      value: diagnostics.nativePlacementStatusLabel,
                      valueColor: diagnostics.isNativePlacementDeferred
                          ? _sessionHealthColor(diagnostics)
                          : null,
                    ),
                    if (diagnostics.hasSessionHealthIssue &&
                        diagnostics.sessionHealthGuidance != null)
                      _DiagnosticsRow(
                        icon: Icons.tips_and_updates_outlined,
                        label: 'Guidance',
                        value: diagnostics.sessionHealthGuidanceLabel,
                        valueColor: _sessionHealthColor(diagnostics),
                      ),
                    _DiagnosticsRow(
                      icon: Icons.tune,
                      label: 'Config',
                      value: diagnostics.sessionConfigStatusLabel,
                      valueColor: diagnostics.hasSessionConfigDowngrades
                          ? Colors.amberAccent.shade100
                          : null,
                    ),
                    _DiagnosticsRow(
                      icon: Icons.sensors,
                      label: 'Sync',
                      value: diagnostics.syncStatusLabel,
                      valueColor: diagnostics.hasNativeSceneFailure
                          ? Colors.redAccent.shade100
                          : null,
                    ),
                    if (diagnostics.hasNativeSceneFailure)
                      _DiagnosticsRow(
                        icon: Icons.error_outline,
                        label: 'Native error',
                        value: diagnostics.nativeSceneFailureMessage ??
                            'Unknown native scene sync error',
                        valueColor: Colors.redAccent.shade100,
                      ),
                    _DiagnosticsRow(
                      icon: Icons.view_in_ar,
                      label: 'Scene',
                      value: diagnostics.sceneChangeLabel,
                    ),
                    if (diagnostics.hasModelPreflight)
                      _DiagnosticsRow(
                        icon: Icons.view_in_ar_outlined,
                        label: 'Models',
                        value: diagnostics.modelPreflightStatusLabel,
                        valueColor: diagnostics.hasModelPreflightIssues
                            ? Colors.amberAccent.shade100
                            : null,
                      ),
                    if (diagnostics.modelPreflight.hasRevalidatedModels)
                      _DiagnosticsRow(
                        icon: Icons.cached_outlined,
                        label: 'Model net',
                        value: _modelPreflightRevalidationLabel(diagnostics),
                      ),
                    if (diagnostics.modelPreflight.hasStaleCacheFallbacks)
                      _DiagnosticsRow(
                        icon: Icons.cloud_off_outlined,
                        label: 'Model cache',
                        value: _modelPreflightStaleCacheFallbackLabel(
                          diagnostics,
                        ),
                        valueColor: Colors.amberAccent.shade100,
                      ),
                    _DiagnosticsRow(
                      icon: Icons.cloud_queue,
                      label: 'Cloud',
                      value: diagnostics.cloudAnchorStatusLabel,
                      valueColor: diagnostics.hasCloudAnchorFailures
                          ? Colors.redAccent.shade100
                          : null,
                    ),
                    _DiagnosticsRow(
                      icon: Icons.sync,
                      label: 'Retry',
                      value: diagnostics.retryStatusLabel,
                    ),
                    _DiagnosticsRow(
                      icon: Icons.event_available,
                      label: 'Care',
                      value: diagnostics.maintenanceStatusLabel,
                    ),
                    if (sessionDiagnosticsReport != null) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Live session report',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DiagnosticsRow(
                        icon: Icons.monitor_heart_outlined,
                        label: 'Report',
                        value: sessionDiagnosticsReport.statusLabel,
                        valueColor: _sessionDiagnosticsReportWarningColor(
                          sessionDiagnosticsReport,
                        ),
                      ),
                      _DiagnosticsRow(
                        icon: Icons.memory_outlined,
                        label: 'Runtime',
                        value: diagnostics.runtimeDiagnosticsStatusLabel,
                        valueColor: diagnostics.hasRuntimeDiagnosticsIssue
                            ? _sessionDiagnosticsReportWarningColor(
                                sessionDiagnosticsReport,
                              )
                            : null,
                      ),
                      if (diagnostics.hasRuntimeDiagnosticsIssue)
                        _DiagnosticsRow(
                          icon: Icons.info_outline,
                          label: 'Runtime detail',
                          value: diagnostics.runtimeDiagnosticsDetailLabel,
                          valueColor: _sessionDiagnosticsReportWarningColor(
                            sessionDiagnosticsReport,
                          ),
                        ),
                      if (diagnostics.runtimeDiagnosticsGuidanceLabel != null)
                        _DiagnosticsRow(
                          icon: Icons.tips_and_updates_outlined,
                          label: 'Runtime action',
                          value: diagnostics.runtimeDiagnosticsGuidanceLabel!,
                          valueColor: _sessionDiagnosticsReportWarningColor(
                            sessionDiagnosticsReport,
                          ),
                        ),
                      _DiagnosticsRow(
                        icon: Icons.event_note_outlined,
                        label: 'Events',
                        value: _sessionDiagnosticsReportEventLabel(
                          sessionDiagnosticsReport,
                        ),
                      ),
                      _DiagnosticsRow(
                        icon: Icons.schedule,
                        label: 'Generated',
                        value: _formatDiagnosticsTime(
                          sessionDiagnosticsReport.generatedAt,
                        ),
                      ),
                      if (diagnostics.hasSessionDiagnosticsReportHistory)
                        _DiagnosticsRow(
                          icon: Icons.history,
                          label: 'History',
                          value: diagnostics
                              .sessionDiagnosticsReportHistoryStatusLabel,
                        ),
                      if (sessionDiagnosticsLatestDiff != null &&
                          sessionDiagnosticsLatestDiff.hasChanges)
                        _DiagnosticsRow(
                          icon: Icons.compare_arrows,
                          label: 'Trend',
                          value: sessionDiagnosticsLatestDiff.statusLabel,
                          valueColor: _sessionDiagnosticsReportDiffColor(
                            sessionDiagnosticsLatestDiff,
                          ),
                        ),
                      for (var index = 0;
                          index < sessionDiagnosticsHistoryReports.length;
                          index += 1)
                        _DiagnosticsRow(
                          icon: Icons.timeline,
                          label: _sessionDiagnosticsHistoryRowLabel(index),
                          value: _sessionDiagnosticsHistoryReportLabel(
                            sessionDiagnosticsHistoryReports[index],
                          ),
                          valueColor: _sessionDiagnosticsReportWarningColor(
                            sessionDiagnosticsHistoryReports[index],
                          ),
                        ),
                      if (sessionDiagnosticsLatestWarning != null)
                        _DiagnosticsRow(
                          icon: Icons.warning_amber,
                          label: 'Latest warning',
                          value: sessionDiagnosticsLatestWarning.displayLabel,
                          valueColor: _sessionDiagnosticsReportWarningColor(
                            sessionDiagnosticsReport,
                          ),
                        ),
                      for (final label in sessionDiagnosticsReportFacetLabels)
                        _DiagnosticsRow(
                          icon: Icons.label_outline,
                          label: 'Facet',
                          value: label,
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey(
                            'ar_scene_diagnostics_session_report_copy_button',
                          ),
                          onPressed: () => _copySessionDiagnosticsReport(
                            sessionDiagnosticsReport,
                          ),
                          icon: const Icon(Icons.content_copy),
                          label: const Text('Copy session report'),
                        ),
                      ),
                    ],
                    if (latestCaptureDiagnostics != null) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Last capture diagnostics',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DiagnosticsRow(
                        icon: Icons.add_a_photo_outlined,
                        label: 'Capture',
                        value: latestCaptureDiagnostics.summaryLabel,
                        valueColor: latestCaptureDiagnostics
                                    .hasNativeSceneFailure ||
                                latestCaptureDiagnostics.hasCloudAnchorFailures
                            ? Colors.redAccent.shade100
                            : null,
                      ),
                      _DiagnosticsRow(
                        icon: Icons.schedule,
                        label: 'Captured',
                        value: _formatDiagnosticsTime(
                          latestCaptureDiagnostics.capturedAt,
                        ),
                      ),
                      if (latestCaptureDiagnostics.captureCapabilityLabel !=
                          null)
                        _DiagnosticsRow(
                          icon: Icons.verified_outlined,
                          label: 'Capture gate',
                          value:
                              latestCaptureDiagnostics.captureCapabilityLabel!,
                        ),
                      if (latestCaptureDiagnostics
                              .captureReadinessGuidanceLabel !=
                          null)
                        _DiagnosticsRow(
                          icon: Icons.tips_and_updates_outlined,
                          label: 'Capture hint',
                          value: latestCaptureDiagnostics
                              .captureReadinessGuidanceLabel!,
                        ),
                      _DiagnosticsRow(
                        icon: Icons.input,
                        label: 'Source',
                        value: latestCaptureDiagnostics.source,
                      ),
                      if (latestCaptureSurfaceLabel != null)
                        _DiagnosticsRow(
                          icon: Icons.wallpaper_outlined,
                          label: 'Surface',
                          value: latestCaptureSurfaceLabel,
                        ),
                      for (final label in latestCaptureDetailLabels)
                        _DiagnosticsRow(
                          icon: Icons.label_outline,
                          label: 'Detail',
                          value: label,
                        ),
                      if (latestCaptureSessionDiagnosticsReport != null) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Captured session report',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DiagnosticsRow(
                          icon: Icons.monitor_heart_outlined,
                          label: 'Report',
                          value:
                              latestCaptureSessionDiagnosticsReport.statusLabel,
                          valueColor: _sessionDiagnosticsReportWarningColor(
                            latestCaptureSessionDiagnosticsReport,
                          ),
                        ),
                        _DiagnosticsRow(
                          icon: Icons.event_note_outlined,
                          label: 'Events',
                          value: _sessionDiagnosticsReportEventLabel(
                            latestCaptureSessionDiagnosticsReport,
                          ),
                        ),
                        _DiagnosticsRow(
                          icon: Icons.schedule,
                          label: 'Generated',
                          value: _formatDiagnosticsTime(
                            latestCaptureSessionDiagnosticsReport.generatedAt,
                          ),
                        ),
                        if (latestCaptureSessionDiagnosticsLatestWarning !=
                            null)
                          _DiagnosticsRow(
                            icon: Icons.warning_amber,
                            label: 'Latest warning',
                            value: latestCaptureSessionDiagnosticsLatestWarning
                                .displayLabel,
                            valueColor: _sessionDiagnosticsReportWarningColor(
                              latestCaptureSessionDiagnosticsReport,
                            ),
                          ),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey(
                            'ar_scene_diagnostics_capture_copy_button',
                          ),
                          onPressed: () => _copyCaptureDiagnostics(
                            latestCaptureDiagnostics,
                          ),
                          icon: const Icon(Icons.content_copy),
                          label: const Text('Copy capture diagnostics'),
                        ),
                      ),
                    ],
                    if (cloudAnchorIssues.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Affected anchors',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          for (final issue in cloudAnchorIssues.take(6))
                            _DiagnosticsIssueTile(
                              issue: issue,
                              onTap: anchorMemoryIds.contains(issue.memoryId)
                                  ? () {
                                      Navigator.pop(context);
                                      _recenterOnMemoryId(
                                        anchors,
                                        issue.memoryId,
                                      );
                                    }
                                  : null,
                            ),
                        ],
                      ),
                      if (cloudAnchorIssues.length > 6) ...[
                        const SizedBox(height: 8),
                        Text(
                          '+${cloudAnchorIssues.length - 6} more affected',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey(
                          'ar_scene_diagnostics_bundle_copy_button',
                        ),
                        onPressed: () => _copySceneDiagnosticsBundle(
                          diagnostics,
                          latestCaptureDiagnostics: latestCaptureDiagnostics,
                        ),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Copy diagnostics bundle'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey(
                          'ar_scene_diagnostics_copy_button',
                        ),
                        onPressed: () => _copySceneDiagnostics(diagnostics),
                        icon: const Icon(Icons.content_copy),
                        label: const Text('Copy diagnostics'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey(
                          'ar_scene_diagnostics_refresh_button',
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _refreshNativeScene();
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(diagnostics.refreshActionLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
