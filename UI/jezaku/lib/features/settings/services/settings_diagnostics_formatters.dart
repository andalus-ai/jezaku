import 'package:ar_engine/ar_engine.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle.dart';

String bundleSummaryLabel(ARSceneDiagnosticsExportBundle? bundle) {
  if (bundle == null) {
    return 'No AR diagnostics bundles cached';
  }
  final labels = <String>[
    bundle.sceneDiagnostics.hudStatusLabel,
    if (bundle.runtimeDiagnosticsSummary.hasIssue)
      bundle.runtimeDiagnosticsSummary.statusLabel,
    if (bundle.sessionDiagnosticsReport != null)
      bundle.sessionDiagnosticsReport!.statusLabel,
    if (bundle.sessionDiagnosticsReportDiff != null)
      bundle.sessionDiagnosticsReportDiff!.statusLabel,
  ];
  return labels.where((label) => label.trim().isNotEmpty).take(2).join(', ');
}

String bundleHistoryLabel(ARSceneDiagnosticsExportBundle bundle) {
  return '${formatBundleExportedAt(bundle.exportedAt)} - '
      '${bundleSummaryLabel(bundle)}';
}

String recentBundleLabel(int index) {
  return switch (index) {
    0 => 'Latest',
    1 => 'Previous',
    _ => 'Earlier',
  };
}

String formatBundleExportedAt(DateTime exportedAt) {
  final local = exportedAt.toLocal();
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String formatDiagnosticsTime(ARCaptureDiagnostics diagnostics) {
  final local = diagnostics.capturedAt.toLocal();
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String twoDigits(int value) => value.toString().padLeft(2, '0');

String formatCacheBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }
  return '${(kib / 1024).toStringAsFixed(1)} MB';
}

