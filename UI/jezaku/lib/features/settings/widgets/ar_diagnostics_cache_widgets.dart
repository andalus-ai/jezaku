import 'dart:convert';
import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/services.dart';
import 'package:jejaku/features/settings/services/settings_diagnostics_formatters.dart';
import 'package:jejaku/features/settings/widgets/diagnostics_value_row.dart';
import 'package:material_ui/material_ui.dart';

class ARDiagnosticsCacheSettingsTile extends StatelessWidget {
  const ARDiagnosticsCacheSettingsTile({
    required this.cache,
    required this.onShowDetails,
    required this.onClearCache,
    super.key,
  });

  final ARCaptureDiagnosticsMemoryCache cache;
  final VoidCallback onShowDetails;
  final VoidCallback? onClearCache;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('ar_diagnostics_cache_tile'),
      leading: const Icon(Icons.view_in_ar_outlined),
      title: const Text('AR diagnostics cache'),
      subtitle: Text(_cacheLabel),
      onTap: onShowDetails,
      trailing: TextButton.icon(
        key: const ValueKey('clear_ar_diagnostics_cache_button'),
        onPressed: onClearCache,
        icon: const Icon(Icons.delete_outline),
        label: const Text('Clear'),
      ),
    );
  }

  String get _cacheLabel {
    final latest = cache.latest;
    if (latest == null) {
      return 'No AR diagnostics cached';
    }
    return '${cache.length} cached capture${cache.length == 1 ? '' : 's'} - '
        '${latest.summaryLabel}';
  }
}

class ARDiagnosticsCacheSheet extends StatefulWidget {
  const ARDiagnosticsCacheSheet({
    required this.cache,
    required this.onClearCache,
    super.key,
  });

  final ARCaptureDiagnosticsMemoryCache cache;
  final VoidCallback? onClearCache;

  @override
  State<ARDiagnosticsCacheSheet> createState() =>
      _ARDiagnosticsCacheSheetState();
}

class _ARDiagnosticsCacheSheetState extends State<ARDiagnosticsCacheSheet> {
  String _timelineQuery = '';
  ARDiagnosticsTimelineFacet? _selectedTimelineFacet;

  @override
  Widget build(BuildContext context) {
    final latest = widget.cache.latest;
    final timeline = widget.cache.toTimeline(includeLifecycleEvents: true);
    final latestTimeline = timeline.latest;
    final latestWarning = timeline.latestWarning;
    final normalizedTimelineQuery = _timelineQuery.trim();
    final baseTimelineQuery = ARDiagnosticsTimelineQuery(
      text: normalizedTimelineQuery,
    );
    final baseTimelineQueryResult = normalizedTimelineQuery.isEmpty
        ? null
        : timeline.query(baseTimelineQuery);
    final selectedTimelineFacet = _selectedTimelineFacet;
    final effectiveTimelineQuery = selectedTimelineFacet == null
        ? baseTimelineQuery
        : selectedTimelineFacet.query.copyWith(text: normalizedTimelineQuery);
    final timelineQueryResult = normalizedTimelineQuery.isEmpty
        ? null
        : timeline.query(effectiveTimelineQuery);
    final timelineMatches =
        timelineQueryResult?.events ?? const <ARDiagnosticsTimelineEvent>[];
    final timelineFacets = baseTimelineQueryResult?.facets(limitPerKind: 3) ??
        const <ARDiagnosticsTimelineFacet>[];
    final timelineMatchTypeLabels = timelineQueryResult
            ?.facetsOfKind(ARDiagnosticsTimelineFacetKind.type, limit: 3)
            .map((facet) => facet.countLabel)
            .toList(growable: false) ??
        const <String>[];
    final timelineMatchSeverityLabels = timelineQueryResult
            ?.facetsOfKind(ARDiagnosticsTimelineFacetKind.severity, limit: 3)
            .map((facet) => facet.countLabel)
            .toList(growable: false) ??
        const <String>[];
    final diagnosticsReport = widget.cache.toReport(
      query: effectiveTimelineQuery,
      syncableOnly: true,
      includeLifecycleEvents: true,
    );
    final payload = const JsonEncoder.withIndent('  ').convert(
      diagnosticsReport.toSyncableMap(),
    );

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
                    'AR diagnostics cache',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('ar_diagnostics_cache_close_button'),
                  tooltip: 'Close diagnostics',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DiagnosticsValueRow(
              label: 'Cached captures',
              value: '${widget.cache.length}',
            ),
            DiagnosticsValueRow(
              label: 'Syncable captures',
              value: '${widget.cache.syncableValues.length}',
            ),
            DiagnosticsValueRow(
              label: 'Latest summary',
              value: latest?.summaryLabel ?? 'No AR diagnostics cached',
            ),
            DiagnosticsValueRow(
              label: 'Timeline events',
              value: '${timeline.length}',
            ),
            DiagnosticsValueRow(
              label: 'Timeline status',
              value: timeline.statusLabel,
            ),
            DiagnosticsValueRow(
              label: 'Timeline latest',
              value: latestTimeline?.summaryLabel ?? 'No timeline events',
            ),
            if (timeline.warningCountLabel != null)
              DiagnosticsValueRow(
                label: 'Timeline warnings',
                value: timeline.warningCountLabel!,
              ),
            if (latestWarning != null)
              DiagnosticsValueRow(
                label: 'Timeline warning',
                value: latestWarning.detailLabel ?? latestWarning.summaryLabel,
              ),
            DiagnosticsValueRow(
              label: 'Latest source',
              value: latest?.source ?? 'None',
            ),
            DiagnosticsValueRow(
              label: 'Latest session',
              value: latest?.sessionId ?? 'Sessionless',
            ),
            DiagnosticsValueRow(
              label: 'Latest capture',
              value: latest == null ? 'None' : formatDiagnosticsTime(latest),
            ),
            DiagnosticsValueRow(
              label: 'Report status',
              value: diagnosticsReport.statusLabel,
            ),
            DiagnosticsValueRow(
              label: 'Report captures',
              value: diagnosticsReport.cacheStatusLabel,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('ar_diagnostics_timeline_search_field'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Search timeline',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _timelineQuery = value;
                  _selectedTimelineFacet = null;
                });
              },
            ),
            if (normalizedTimelineQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              DiagnosticsValueRow(
                label: 'Timeline matches',
                value: '${timelineQueryResult?.length ?? 0}',
              ),
              if (selectedTimelineFacet != null)
                DiagnosticsValueRow(
                  label: 'Active facet',
                  value: selectedTimelineFacet.countLabel,
                ),
              if (timelineFacets.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final facet in timelineFacets)
                      FilterChip(
                        key: ValueKey(
                          'ar_diagnostics_facet_'
                          '${facet.kind.name}_${facet.value}',
                        ),
                        label: Text(facet.countLabel),
                        selected: facet == selectedTimelineFacet,
                        onSelected: (selected) {
                          setState(() {
                            _selectedTimelineFacet = selected ? facet : null;
                          });
                        },
                      ),
                  ],
                ),
              ],
              if (timelineQueryResult != null && timelineQueryResult.isNotEmpty)
                DiagnosticsValueRow(
                  label: 'Match status',
                  value: timelineQueryResult.statusLabel,
                ),
              if (timelineQueryResult?.warningCountLabel != null)
                DiagnosticsValueRow(
                  label: 'Match warnings',
                  value: timelineQueryResult!.warningCountLabel!,
                ),
              if (timelineMatchTypeLabels.isNotEmpty)
                DiagnosticsValueRow(
                  label: 'Match types',
                  value: timelineMatchTypeLabels.join(', '),
                ),
              if (timelineMatchSeverityLabels.isNotEmpty)
                DiagnosticsValueRow(
                  label: 'Match severities',
                  value: timelineMatchSeverityLabels.join(', '),
                ),
              if (timelineMatches.isEmpty)
                const DiagnosticsValueRow(
                  label: 'Match',
                  value: 'No timeline events match',
                )
              else
                for (final event in timelineMatches.take(5))
                  DiagnosticsValueRow(
                    label: 'Match',
                    value: event.displayLabel,
                  ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cache payload',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('copy_ar_diagnostics_cache_button'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: payload));
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('AR diagnostics cache copied.'),
                        ),
                      );
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy'),
                ),
                TextButton.icon(
                  key:
                      const ValueKey('sheet_clear_ar_diagnostics_cache_button'),
                  onPressed: widget.onClearCache,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              payload,
              key: const ValueKey('ar_diagnostics_cache_payload'),
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

