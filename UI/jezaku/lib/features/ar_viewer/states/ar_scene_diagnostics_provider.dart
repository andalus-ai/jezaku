import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_store.dart';

final arMemorySceneDiagnosticsProvider = NotifierProvider<
    ARMemorySceneDiagnosticsController, ARMemorySceneDiagnostics>(
  ARMemorySceneDiagnosticsController.new,
);

class ARMemorySceneDiagnosticsController
    extends Notifier<ARMemorySceneDiagnostics> {
  @override
  ARMemorySceneDiagnostics build() {
    return ref
            .read(arMemorySceneDiagnosticsStoreProvider)
            .loadLastDiagnostics() ??
        const ARMemorySceneDiagnostics();
  }

  void startSession(String sessionId, {DateTime? startedAt}) {
    final current = state;
    if (current.sessionId == sessionId &&
        !current.isPendingForSession(sessionId)) {
      return;
    }
    _set(
      ARMemorySceneDiagnostics.sessionStarted(
        sessionId: sessionId,
        startedAt: startedAt,
      ),
    );
  }

  void resetSession(String sessionId, {DateTime? startedAt}) {
    final current = state;
    if (current.sessionId != sessionId ||
        current.isPendingForSession(sessionId)) {
      return;
    }
    _set(
      ARMemorySceneDiagnostics.sessionStarted(
        sessionId: sessionId,
        startedAt: startedAt ?? current.sessionStartedAt,
      ),
    );
  }

  void updateForSession(
    String sessionId,
    ARMemorySceneDiagnostics diagnostics,
  ) {
    final current = state;
    if (current.sessionId != sessionId) {
      return;
    }
    final next = diagnostics.forSession(
      sessionId: sessionId,
      sessionStartedAt: current.sessionStartedAt,
    );
    var merged = next;
    if (!merged.hasSessionHealth && current.sessionHealthAssessment != null) {
      merged = merged.withSessionHealthAssessment(
        current.sessionHealthAssessment,
      );
    }
    if (!merged.hasSessionDiagnosticsReportHistory &&
        current.hasSessionDiagnosticsReportHistory) {
      merged = merged.copyWith(
        sessionDiagnosticsReportHistory:
            current.sessionDiagnosticsReportHistory,
      );
    }
    if (!merged.hasSessionDiagnosticsReport &&
        current.sessionDiagnosticsReport != null) {
      merged = merged.withSessionDiagnosticsReport(
        current.sessionDiagnosticsReport,
      );
    }
    _set(merged);
  }

  void updateSessionConfigForSession(
    String sessionId, {
    required Iterable<String> unsupportedFeatureKeys,
  }) {
    final current = state;
    if (current.sessionId != sessionId) {
      return;
    }
    _set(current.withUnsupportedSessionFeatureKeys(unsupportedFeatureKeys));
  }

  void updateSessionConfigResolutionForSession(
    String sessionId,
    ARSessionConfigResolution resolution,
  ) {
    updateSessionConfigForSession(
      sessionId,
      unsupportedFeatureKeys: resolution.unsupportedFeatureKeys,
    );
  }

  void updateSessionHealthForSession(
    String sessionId,
    ARSessionHealthSnapshot health,
  ) {
    final current = state;
    if (current.sessionId != sessionId) {
      return;
    }
    _set(current.withSessionHealth(health));
  }

  void updateSessionHealthAssessmentForSession(
    String sessionId,
    ARSessionHealthAssessment assessment,
  ) {
    final current = state;
    if (current.sessionId != sessionId) {
      return;
    }
    _set(current.withSessionHealthAssessment(assessment));
  }

  void updateSessionDiagnosticsReportForSession(
    String sessionId,
    ARDiagnosticsReport report,
  ) {
    final current = state;
    if (current.sessionId != sessionId) {
      return;
    }
    _set(current.withSessionDiagnosticsReport(report));
  }

  void clearSessionHealthForSession(String sessionId) {
    final current = state;
    if (current.sessionId != sessionId) {
      return;
    }
    _set(current.withSessionHealthAssessment(null));
  }

  Map<String, dynamic> snapshot() {
    return state.toMap();
  }

  bool restore(ARMemorySceneDiagnostics diagnostics,
      {String? expectedSessionId}) {
    final diagnosticsSessionId = diagnostics.sessionId;
    if (expectedSessionId != null &&
        diagnosticsSessionId != expectedSessionId) {
      return false;
    }

    final currentSessionId = state.sessionId;
    if (currentSessionId != null && currentSessionId != diagnosticsSessionId) {
      return false;
    }

    _set(diagnostics);
    return true;
  }

  bool restoreFromMap(
    Map<dynamic, dynamic> map, {
    String? expectedSessionId,
  }) {
    return restore(
      ARMemorySceneDiagnostics.fromMap(map),
      expectedSessionId: expectedSessionId,
    );
  }

  void endSession(String sessionId) {
    if (state.sessionId != sessionId) {
      return;
    }
    clear();
  }

  void update(ARMemorySceneDiagnostics diagnostics) {
    _set(diagnostics);
  }

  void clear() {
    state = const ARMemorySceneDiagnostics();
    ref.read(arMemorySceneDiagnosticsStoreProvider).clearLastDiagnostics();
  }

  void _set(ARMemorySceneDiagnostics diagnostics) {
    state = diagnostics;
    ref
        .read(arMemorySceneDiagnosticsStoreProvider)
        .saveLastDiagnostics(diagnostics);
  }
}
