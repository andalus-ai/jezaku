import 'package:ar_engine/ar_engine.dart';

/// Summarizes backend AR runtime diagnostics for viewer UI and export payloads.
class ARSceneRuntimeDiagnosticsSummary {
  ARSceneRuntimeDiagnosticsSummary._({
    required this.hasReport,
    required Iterable<ARDiagnosticsTimelineEvent> events,
    String? statusLabel,
    String? detailLabel,
    bool? hasIssue,
    String? code,
    String? source,
    String? backendLabel,
    String? guidanceLabel,
  })  : events = List<ARDiagnosticsTimelineEvent>.unmodifiable(events),
        _statusLabel = _nonEmptyString(statusLabel),
        _detailLabel = _nonEmptyString(detailLabel),
        _hasIssue = hasIssue,
        _code = _nonEmptyString(code),
        _source = _nonEmptyString(source),
        _backendLabel = _nonEmptyString(backendLabel),
        _guidanceLabel = _nonEmptyString(guidanceLabel);

  factory ARSceneRuntimeDiagnosticsSummary.fromReport(
    ARDiagnosticsReport? report,
  ) {
    if (report == null) {
      return ARSceneRuntimeDiagnosticsSummary.pending;
    }
    return ARSceneRuntimeDiagnosticsSummary._(
      hasReport: true,
      events: report.timeline.values.where(_isRuntimeDiagnosticsEvent),
    );
  }

  factory ARSceneRuntimeDiagnosticsSummary.fromCaptureDiagnostics(
    ARCaptureDiagnostics? diagnostics,
  ) {
    if (diagnostics == null) {
      return ARSceneRuntimeDiagnosticsSummary.pending;
    }
    final reportSummary = ARSceneRuntimeDiagnosticsSummary.fromReport(
      ARDiagnosticsReport.tryFromMap(
        diagnostics.extra['sessionDiagnosticsReport'],
      ),
    );
    if (reportSummary.hasReport) {
      return reportSummary;
    }

    final statusLabel = _nonEmptyString(
      diagnostics.extra['runtimeDiagnosticsStatusLabel'],
    );
    final detailLabel = _nonEmptyString(
      diagnostics.extra['runtimeDiagnosticsDetailLabel'],
    );
    final hasIssue = diagnostics.extra['hasRuntimeDiagnosticsIssue'];
    final code = _nonEmptyString(
      diagnostics.extra['runtimeDiagnosticsCode'],
    );
    final source = _nonEmptyString(
      diagnostics.extra['runtimeDiagnosticsSource'],
    );
    final backendLabel = _nonEmptyString(
      diagnostics.extra['runtimeDiagnosticsBackendLabel'],
    );
    final guidanceLabel = _nonEmptyString(
      diagnostics.extra['runtimeDiagnosticsGuidanceLabel'],
    );
    if (statusLabel == null &&
        detailLabel == null &&
        hasIssue is! bool &&
        code == null &&
        source == null &&
        backendLabel == null &&
        guidanceLabel == null) {
      return ARSceneRuntimeDiagnosticsSummary.pending;
    }

    return ARSceneRuntimeDiagnosticsSummary._(
      hasReport: true,
      events: const <ARDiagnosticsTimelineEvent>[],
      statusLabel: statusLabel,
      detailLabel: detailLabel,
      hasIssue: hasIssue is bool ? hasIssue : null,
      code: code,
      source: source,
      backendLabel: backendLabel,
      guidanceLabel: guidanceLabel,
    );
  }

  static final ARSceneRuntimeDiagnosticsSummary pending =
      ARSceneRuntimeDiagnosticsSummary._(
    hasReport: false,
    events: const <ARDiagnosticsTimelineEvent>[],
  );

  final bool hasReport;
  final List<ARDiagnosticsTimelineEvent> events;
  final String? _statusLabel;
  final String? _detailLabel;
  final bool? _hasIssue;
  final String? _code;
  final String? _source;
  final String? _backendLabel;
  final String? _guidanceLabel;

  ARDiagnosticsTimelineEvent? get latestEvent {
    return _latestRuntimeDiagnosticsEvent(events);
  }

  ARDiagnosticsTimelineEvent? get latestIssue {
    return _latestRuntimeDiagnosticsEvent(
      events.where((event) => event.isWarning),
    );
  }

  bool get hasEvent => latestEvent != null;

  bool get hasIssue => _hasIssue ?? latestIssue != null;

  String get statusLabel {
    final override = _statusLabel;
    if (override != null) {
      return override;
    }
    final event = latestIssue ?? latestEvent;
    if (event == null) {
      return hasReport ? 'Backend runtime nominal' : 'Backend runtime pending';
    }
    final backendLabel = _runtimeBackendLabel(
      event.sessionLifecycleEvent?.metadata['backend'],
    );
    if (backendLabel == null) {
      return event.summaryLabel;
    }
    return '$backendLabel: ${event.summaryLabel}';
  }

  String get detailLabel {
    final override = _detailLabel;
    if (override != null) {
      return override;
    }
    final event = latestIssue ?? latestEvent;
    if (event == null) {
      return hasReport
          ? 'No backend runtime issue reported'
          : 'Runtime diagnostics have not reported yet';
    }
    return event.detailLabel ?? event.displayLabel;
  }

  String? get code {
    return _code ?? (latestIssue ?? latestEvent)?.sessionLifecycleEvent?.code;
  }

  String? get source {
    return _source ?? (latestIssue ?? latestEvent)?.source;
  }

  String? get backendLabel {
    return _backendLabel ??
        _runtimeBackendLabel(
          (latestIssue ?? latestEvent)
              ?.sessionLifecycleEvent
              ?.metadata['backend'],
        );
  }

  String? get guidanceLabel {
    final override = _guidanceLabel;
    if (override != null) {
      return override;
    }
    if (!hasIssue) {
      return null;
    }
    return _runtimeGuidanceLabel(code);
  }

  Map<String, Object?> toSummaryMap() => <String, Object?>{
        'runtimeDiagnosticsStatusLabel': statusLabel,
        'runtimeDiagnosticsDetailLabel': detailLabel,
        'hasRuntimeDiagnosticsIssue': hasIssue,
        if (code != null) 'runtimeDiagnosticsCode': code,
        if (source != null) 'runtimeDiagnosticsSource': source,
        if (backendLabel != null)
          'runtimeDiagnosticsBackendLabel': backendLabel,
        if (guidanceLabel != null)
          'runtimeDiagnosticsGuidanceLabel': guidanceLabel,
      };
}

bool _isRuntimeDiagnosticsEvent(ARDiagnosticsTimelineEvent event) {
  final lifecycleEvent = event.sessionLifecycleEvent;
  if (lifecycleEvent == null) {
    return false;
  }
  final code = lifecycleEvent.code;
  return (code != null && code.startsWith('runtime_')) ||
      lifecycleEvent.source.endsWith('_runtime') ||
      event.source.endsWith('_runtime');
}

ARDiagnosticsTimelineEvent? _latestRuntimeDiagnosticsEvent(
  Iterable<ARDiagnosticsTimelineEvent> events,
) {
  ARDiagnosticsTimelineEvent? latest;
  for (final event in events) {
    if (latest == null ||
        !event.recordedAt.toUtc().isBefore(latest.recordedAt.toUtc())) {
      latest = event;
    }
  }
  return latest;
}

String? _runtimeBackendLabel(Object? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.toString().trim();
  if (normalized.isEmpty) {
    return null;
  }
  return switch (normalized.toLowerCase()) {
    'arcore' => 'ARCore',
    'arkit' => 'ARKit',
    'desktop_camera' => 'Desktop camera',
    _ => normalized,
  };
}

String _runtimeGuidanceLabel(String? code) {
  return switch (code) {
    'runtime_native_session_unavailable' =>
      'Restart the AR session and confirm camera permission before placing objects.',
    'runtime_camera_frame_unavailable' =>
      'Keep the camera view unobstructed, move the device slightly, and wait for the first AR frame.',
    'runtime_renderer_unavailable' =>
      'Reopen the AR viewer so the renderer can attach to the native session.',
    'runtime_model_load_failed' =>
      'Repair the model cache or re-download the object before placing it again.',
    'runtime_model_fallback_used' =>
      'Review the model cache when network is available; a fallback renderer was used.',
    'runtime_texture_load_failed' =>
      'Repair cached textures or retry model preload before capturing the scene.',
    'runtime_stale_model_callback_ignored' =>
      'Retry placement if the model is missing; an old load callback was ignored.',
    _ =>
      'Review runtime details and restart the AR session if the issue persists.',
  };
}

String? _nonEmptyString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
