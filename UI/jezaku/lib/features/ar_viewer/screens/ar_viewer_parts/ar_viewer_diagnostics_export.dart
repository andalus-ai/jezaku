part of '../ar_viewer_screen.dart';

/// Copying diagnostics to the clipboard and managing the AR debug log.
extension _ARViewerDiagnosticsExport on _ARViewerScreenState {
  Future<void> _copySceneDiagnosticsBundle(
    ARMemorySceneDiagnostics diagnostics, {
    ARCaptureDiagnostics? latestCaptureDiagnostics,
  }) async {
    final bundle = ARSceneDiagnosticsExportBundle.fromDiagnostics(
      sceneDiagnostics: diagnostics,
      latestCaptureDiagnostics: latestCaptureDiagnostics,
    );
    final payload = const JsonEncoder.withIndent('  ').convert(
      bundle.toMap(),
    );
    await Clipboard.setData(ClipboardData(text: payload));
    ref.read(arSceneDiagnosticsExportBundleCacheStoreProvider).saveBundle(
          bundle,
        );
    ref.invalidate(arSceneDiagnosticsExportBundleCacheProvider);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('AR diagnostics bundle copied')),
      );
  }

  Future<void> _copySceneDiagnostics(
    ARMemorySceneDiagnostics diagnostics,
  ) async {
    final payload = const JsonEncoder.withIndent('  ').convert(
      diagnostics.toMap(),
    );
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('AR diagnostics copied')),
      );
  }

  Future<void> _copyCaptureDiagnostics(
    ARCaptureDiagnostics diagnostics,
  ) async {
    final payload = const JsonEncoder.withIndent('  ').convert(
      diagnostics.toSyncableMap() ?? diagnostics.toMap(),
    );
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('AR capture diagnostics copied')),
      );
  }

  Future<void> _copySessionDiagnosticsReport(
    ARDiagnosticsReport report,
  ) async {
    final payload = const JsonEncoder.withIndent('  ').convert(
      report.toSyncableMap(),
    );
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('AR session report copied')),
      );
  }

  /// Copies the persisted debug log (survives a dropped debug connection).
  Future<void> _copyDebugLog() async {
    final log = ref.read(arDebugLogProvider);
    final text = await log.export();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    _showSnack(
      text.isEmpty
          ? 'Debug log is empty. Turn it on and reproduce the problem.'
          : 'Debug log copied (${text.split('\n').length} lines)',
    );
  }

  Future<void> _clearDebugLog() async {
    await ref.read(arDebugLogProvider).clear();
    if (!mounted) {
      return;
    }
    _showSnack('Debug log cleared');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
