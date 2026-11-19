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
        ARSessionReportComparison.latestDiff(diagnostics);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;

        Widget sectionHeading(String title) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Divider(color: colors.outlineVariant, height: 1),
                ),
              ],
            ),
          );
        }

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
                        Expanded(
                          child: Text(
                            'Native scene diagnostics',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close diagnostics',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          color: colors.onSurfaceVariant,
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
                      backgroundColor: _sceneDiagnosticsColor(diagnostics, colors),
                    ),
                    sectionHeading('OVERVIEW'),
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
                          ? _sessionHealthColor(diagnostics, colors)
                          : null,
                    ),
                    if (diagnostics.sessionReadiness != null)
                      _DiagnosticsRow(
                        icon: Icons.fact_check_outlined,
                        label: 'Readiness',
                        value: diagnostics.sessionReadinessLabel,
                        valueColor: diagnostics.isSessionReadyForPlacement
                            ? null
                            : _sessionHealthColor(diagnostics, colors),
                      ),
                    _DiagnosticsRow(
                      icon: Icons.add_location_alt_outlined,
                      label: 'Placement',
                      value: diagnostics.nativePlacementStatusLabel,
                      valueColor: diagnostics.isNativePlacementDeferred
                          ? _sessionHealthColor(diagnostics, colors)
                          : null,
                    ),
                    if (diagnostics.hasSessionHealthIssue &&
                        diagnostics.sessionHealthGuidance != null)
                      _DiagnosticsRow(
                        icon: Icons.tips_and_updates_outlined,
                        label: 'Guidance',
                        value: diagnostics.sessionHealthGuidanceLabel,
                        valueColor: _sessionHealthColor(diagnostics, colors),
                      ),
                    sectionHeading('RUNTIME & SYNCHRONIZATION'),
                    _DiagnosticsRow(
                      icon: Icons.tune,
                      label: 'Config',
                      value: diagnostics.sessionConfigStatusLabel,
                      valueColor: diagnostics.hasSessionConfigDowngrades
                          ? colors.tertiary
                          : null,
                    ),
                    _DiagnosticsRow(
                      icon: Icons.sensors,
                      label: 'Sync',
                      value: diagnostics.syncStatusLabel,
                      valueColor: diagnostics.hasNativeSceneFailure
                          ? colors.error
                          : null,
                    ),
                    if (diagnostics.hasNativeSceneFailure)
                      _DiagnosticsRow(
                        icon: Icons.error_outline,
                        label: 'Native error',
                        value: diagnostics.nativeSceneFailureMessage ??
                            'Unknown native scene sync error',
                        valueColor: colors.error,
                      ),
                    _DiagnosticsRow(
                      icon: Icons.view_in_ar,
                      label: 'Scene',
                      value: diagnostics.sceneChangeLabel,
                    ),
                    sectionHeading('ASSETS & CACHE'),
                    if (diagnostics.hasModelPreflight)
                      _DiagnosticsRow(
                        icon: Icons.view_in_ar_outlined,
                        label: 'Models',
                        value: diagnostics.modelPreflightStatusLabel,
                        valueColor: diagnostics.hasModelPreflightIssues
                            ? colors.tertiary
                            : null,
                      ),
                    if (diagnostics.modelPreflight.hasRevalidatedModels)
                      _DiagnosticsRow(
                        icon: Icons.cached_outlined,
                        label: 'Model net',
                        value: ARDiagnosticsLabels.modelRevalidation(diagnostics),
                      ),
                    if (diagnostics.modelPreflight.hasStaleCacheFallbacks)
                      _DiagnosticsRow(
                        icon: Icons.cloud_off_outlined,
                        label: 'Model cache',
                        value: ARDiagnosticsLabels.modelStaleCacheFallback(
                          diagnostics,
                        ),
                        valueColor: colors.tertiary,
                      ),
                    _DiagnosticsRow(
                      icon: Icons.cloud_queue,
                      label: 'Cloud',
                      value: diagnostics.cloudAnchorStatusLabel,
                      valueColor: diagnostics.hasCloudAnchorFailures
                          ? colors.error
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
                      sectionHeading('REPORTS & HISTORY'),
                      Text(
                        'Live session report',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DiagnosticsRow(
                        icon: Icons.monitor_heart_outlined,
                        label: 'Report',
                        value: sessionDiagnosticsReport.statusLabel,
                        valueColor: ARSessionReportComparison.warningColor(
                          sessionDiagnosticsReport,
                        ),
                      ),
                      _DiagnosticsRow(
                        icon: Icons.memory_outlined,
                        label: 'Runtime',
                        value: diagnostics.runtimeDiagnosticsStatusLabel,
                        valueColor: diagnostics.hasRuntimeDiagnosticsIssue
                            ? ARSessionReportComparison.warningColor(
                                sessionDiagnosticsReport,
                              )
                            : null,
                      ),
                      if (diagnostics.hasRuntimeDiagnosticsIssue)
                        _DiagnosticsRow(
                          icon: Icons.info_outline,
                          label: 'Runtime detail',
                          value: diagnostics.runtimeDiagnosticsDetailLabel,
                          valueColor: ARSessionReportComparison.warningColor(
                            sessionDiagnosticsReport,
                          ),
                        ),
                      if (diagnostics.runtimeDiagnosticsGuidanceLabel != null)
                        _DiagnosticsRow(
                          icon: Icons.tips_and_updates_outlined,
                          label: 'Runtime action',
                          value: diagnostics.runtimeDiagnosticsGuidanceLabel!,
                          valueColor: ARSessionReportComparison.warningColor(
                            sessionDiagnosticsReport,
                          ),
                        ),
                      _DiagnosticsRow(
                        icon: Icons.event_note_outlined,
                        label: 'Events',
                        value: ARDiagnosticsLabels.reportEvents(
                          sessionDiagnosticsReport,
                        ),
                      ),
                      _DiagnosticsRow(
                        icon: Icons.schedule,
                        label: 'Generated',
                        value: ARDiagnosticsLabels.time(
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
                          valueColor: ARSessionReportComparison.diffColor(
                            sessionDiagnosticsLatestDiff,
                          ),
                        ),
                      for (var index = 0;
                          index < sessionDiagnosticsHistoryReports.length;
                          index += 1)
                        _DiagnosticsRow(
                          icon: Icons.timeline,
                          label: ARDiagnosticsLabels.historyRow(index),
                          value: ARDiagnosticsLabels.historyReport(
                            sessionDiagnosticsHistoryReports[index],
                          ),
                          valueColor: ARSessionReportComparison.warningColor(
                            sessionDiagnosticsHistoryReports[index],
                          ),
                        ),
                      if (sessionDiagnosticsLatestWarning != null)
                        _DiagnosticsRow(
                          icon: Icons.warning_amber,
                          label: 'Latest warning',
                          value: sessionDiagnosticsLatestWarning.displayLabel,
                          valueColor: ARSessionReportComparison.warningColor(
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
                      sectionHeading('LAST CAPTURE'),
                      Text(
                        'Last capture diagnostics',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
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
                            ? colors.error
                            : null,
                      ),
                      _DiagnosticsRow(
                        icon: Icons.schedule,
                        label: 'Captured',
                        value: ARDiagnosticsLabels.time(
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
                        Text(
                          'Captured session report',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DiagnosticsRow(
                          icon: Icons.monitor_heart_outlined,
                          label: 'Report',
                          value:
                              latestCaptureSessionDiagnosticsReport.statusLabel,
                          valueColor: ARSessionReportComparison.warningColor(
                            latestCaptureSessionDiagnosticsReport,
                          ),
                        ),
                        _DiagnosticsRow(
                          icon: Icons.event_note_outlined,
                          label: 'Events',
                          value: ARDiagnosticsLabels.reportEvents(
                            latestCaptureSessionDiagnosticsReport,
                          ),
                        ),
                        _DiagnosticsRow(
                          icon: Icons.schedule,
                          label: 'Generated',
                          value: ARDiagnosticsLabels.time(
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
                            valueColor: ARSessionReportComparison.warningColor(
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
                      sectionHeading('AFFECTED ANCHORS'),
                      Text(
                        'Affected anchors',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
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
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                    sectionHeading('DEBUG LOG'),
                    ARDebugLogControls(
                      log: ref.read(arDebugLogProvider),
                      onCopy: _copyDebugLog,
                      onClear: _clearDebugLog,
                    ),
                    sectionHeading('ACTIONS & EXPORT'),
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
