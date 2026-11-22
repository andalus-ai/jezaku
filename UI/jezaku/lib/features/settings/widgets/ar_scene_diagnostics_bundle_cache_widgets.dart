import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle_cache.dart';
import 'package:jejaku/features/settings/services/settings_diagnostics_formatters.dart';
import 'package:jejaku/features/settings/widgets/diagnostics_value_row.dart';
import 'package:material_ui/material_ui.dart';

class ARSceneDiagnosticsBundleCacheSettingsTile extends StatelessWidget {
  const ARSceneDiagnosticsBundleCacheSettingsTile({
    required this.cache,
    required this.onShowDetails,
    required this.onClearCache,
    super.key,
  });

  final ARSceneDiagnosticsExportBundleCache cache;
  final VoidCallback onShowDetails;
  final VoidCallback? onClearCache;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('ar_diagnostics_bundle_cache_tile'),
      leading: const Icon(Icons.inventory_2_outlined),
      title: const Text('AR diagnostics bundles'),
      subtitle: Text(_cacheLabel),
      onTap: onShowDetails,
      trailing: TextButton.icon(
        key: const ValueKey('clear_ar_diagnostics_bundle_cache_button'),
        onPressed: onClearCache,
        icon: const Icon(Icons.delete_outline),
        label: const Text('Clear'),
      ),
    );
  }

  String get _cacheLabel {
    final latest = cache.latest;
    if (latest == null) {
      return 'No AR diagnostics bundles cached';
    }
    return '${cache.length} cached bundle${cache.length == 1 ? '' : 's'} - '
        '${bundleSummaryLabel(latest)}';
  }
}

class ARSceneDiagnosticsBundleCacheSheet extends StatelessWidget {
  const ARSceneDiagnosticsBundleCacheSheet({
    required this.cache,
    required this.onClearCache,
    super.key,
  });

  final ARSceneDiagnosticsExportBundleCache cache;
  final VoidCallback? onClearCache;

  @override
  Widget build(BuildContext context) {
    final latest = cache.latest;
    final payload = const JsonEncoder.withIndent('  ').convert(cache.toMap());
    final recentBundles = cache.values.reversed.take(5).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'AR diagnostics bundles',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey(
                    'ar_diagnostics_bundle_cache_close_button',
                  ),
                  tooltip: 'Close bundle cache',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DiagnosticsValueRow(
              label: 'Cached bundles',
              value: '${cache.length}',
            ),
            DiagnosticsValueRow(
              label: 'Latest summary',
              value: bundleSummaryLabel(latest),
            ),
            DiagnosticsValueRow(
              label: 'Latest export',
              value: latest == null
                  ? 'None'
                  : formatBundleExportedAt(latest.exportedAt),
            ),
            DiagnosticsValueRow(
              label: 'Latest session',
              value: latest?.sceneDiagnostics.sessionId ?? 'Sessionless',
            ),
            DiagnosticsValueRow(
              label: 'Latest report',
              value: latest?.sessionDiagnosticsReport?.statusLabel ??
                  'No session report',
            ),
            DiagnosticsValueRow(
              label: 'Latest runtime',
              value: latest?.runtimeDiagnosticsSummary.statusLabel ??
                  'No runtime diagnostics',
            ),
            if (latest?.runtimeDiagnosticsSummary.hasIssue ?? false)
              DiagnosticsValueRow(
                label: 'Runtime detail',
                value: latest!.runtimeDiagnosticsSummary.detailLabel,
              ),
            if (latest?.runtimeDiagnosticsSummary.guidanceLabel != null)
              DiagnosticsValueRow(
                label: 'Runtime action',
                value: latest!.runtimeDiagnosticsSummary.guidanceLabel!,
              ),
            if (latest?.sessionDiagnosticsReportDiff != null)
              DiagnosticsValueRow(
                label: 'Latest trend',
                value: latest!.sessionDiagnosticsReportDiff!.statusLabel,
              ),
            DiagnosticsValueRow(
              label: 'Latest capture',
              value: latest?.latestCaptureDiagnostics?.summaryLabel ??
                  'No capture diagnostics',
            ),
            if (recentBundles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Recent bundles',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              for (var index = 0; index < recentBundles.length; index++)
                DiagnosticsValueRow(
                  label: recentBundleLabel(index),
                  value: bundleHistoryLabel(recentBundles[index]),
                ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bundle payload',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey(
                    'copy_ar_diagnostics_bundle_cache_button',
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: payload));
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('AR diagnostics bundles copied.'),
                        ),
                      );
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy'),
                ),
                TextButton.icon(
                  key: const ValueKey(
                    'sheet_clear_ar_diagnostics_bundle_cache_button',
                  ),
                  onPressed: onClearCache,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              payload,
              key: const ValueKey('ar_diagnostics_bundle_cache_payload'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

