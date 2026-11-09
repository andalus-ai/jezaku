import 'dart:convert';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle_cache.dart';
import 'package:jejaku/features/ar_viewer/services/ar_model_asset_cache_provider.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_export_bundle_store.dart';
import 'package:jejaku/features/camera/services/ar_capture_diagnostics_cache_store.dart';
import 'package:jejaku/features/camera/states/capture_session_provider.dart';
import 'package:jejaku/features/home/services/anchor_media_maintenance_service.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/settings/screens/privacy_safety_screen.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:jejaku/features/settings/widgets/ar_model_cache_settings_tile.dart';
import 'package:jejaku/features/sync/services/anchor_media_upload_queue_maintenance_service.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    ref.watch(anchorMediaRepositoryRevisionProvider);
    final anchors = ref.watch(nearbyAnchorsProvider);
    final mediaRepository = ref.watch(anchorMediaRepositoryProvider);
    final arDiagnosticsCache = ref.watch(arCaptureDiagnosticsCacheProvider);
    final arDiagnosticsBundleCache =
        ref.watch(arSceneDiagnosticsExportBundleCacheProvider);
    final modelCacheStats = ref.watch(arModelAssetCacheStatsProvider);
    final modelCacheEntries = ref.watch(arModelAssetCacheEntriesProvider);
    final modelCacheIntegrity = ref.watch(arModelAssetCacheIntegrityProvider);
    final modelCacheBytes = modelCacheStats.when<int>(
      data: (stats) => stats.byteLength,
      error: (error, stackTrace) => 0,
      loading: () => 0,
    );
    final storageReport = mediaRepository.inspectStorage();
    final cachedMediaBytes = mediaRepository.cachedByteLength + modelCacheBytes;
    final mediaMaintenancePlan = ref
        .watch(anchorMediaMaintenanceServiceProvider)
        .plan(memories: anchors, repository: mediaRepository);
    final mediaUploadQueueMaintenancePlan =
        ref.watch(anchorMediaUploadQueueMaintenanceServiceProvider).plan(
              memories: anchors,
              uploadEntries: ref.watch(anchorMediaUploadQueueProvider),
            );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _SettingsSectionHeader(title: 'Notifications'),
          SwitchListTile(
            key: const ValueKey('nearby_notifications_switch'),
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Nearby notifications'),
            subtitle: const Text('Alert when friends leave anchors nearby'),
            value: settings.nearbyNotifications,
            onChanged: controller.setNearbyNotifications,
          ),
          const Divider(),
          const _SettingsSectionHeader(title: 'Privacy and anchoring'),
          SwitchListTile(
            key: const ValueKey('private_default_switch'),
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Private by default'),
            subtitle: const Text('Start new memories as private'),
            value: settings.privateByDefault,
            onChanged: controller.setPrivateByDefault,
          ),
          SwitchListTile(
            key: const ValueKey('high_accuracy_switch'),
            secondary: const Icon(Icons.gps_fixed),
            title: const Text('High accuracy anchoring'),
            subtitle: const Text('Use tighter GPS and orientation checks'),
            value: settings.highAccuracyMode,
            onChanged: controller.setHighAccuracyMode,
          ),
          const Divider(),
          const _SettingsSectionHeader(title: 'Family safety'),
          SwitchListTile(
            key: const ValueKey('family_location_alerts_switch'),
            secondary: const Icon(Icons.location_searching_outlined),
            title: const Text('Location boundary alerts'),
            subtitle: const Text('Notify guardians when a child exits a zone'),
            value: settings.familyLocationAlerts,
            onChanged: controller.setFamilyLocationAlerts,
          ),
          SwitchListTile(
            key: const ValueKey('guardian_digest_switch'),
            secondary: const Icon(Icons.summarize_outlined),
            title: const Text('Weekly guardian digest'),
            subtitle: const Text('Send a summary of screen time and anchors'),
            value: settings.weeklyGuardianDigest,
            onChanged: controller.setWeeklyGuardianDigest,
          ),
          SwitchListTile(
            key: const ValueKey('approval_reminders_switch'),
            secondary: const Icon(Icons.fact_check_outlined),
            title: const Text('Approval reminders'),
            subtitle: const Text('Remind guardians about pending requests'),
            value: settings.approvalReminders,
            onChanged: controller.setApprovalReminders,
          ),
          const Divider(),
          _StorageSettingsTile(
            cachedMediaMb: settings.cachedMediaMb,
            cachedMediaBytes: cachedMediaBytes,
            storageReport: storageReport,
            onClearCache: () => _confirmClearCache(
              context,
              controller.clearCachedMedia,
            ),
          ),
          ARModelCacheSettingsTile(
            stats: modelCacheStats,
            entries: modelCacheEntries,
            integrity: modelCacheIntegrity,
            onRepairIntegrity: () => ref
                .read(arModelAssetCacheMaintenanceProvider)
                .repairIntegrity(),
            onRepairManifests: () => ref
                .read(arModelAssetCacheMaintenanceProvider)
                .repairManifests(),
          ),
          _ARDiagnosticsCacheSettingsTile(
            cache: arDiagnosticsCache,
            onShowDetails: () => _showARDiagnosticsCache(
              context,
              ref,
              arDiagnosticsCache,
            ),
            onClearCache: arDiagnosticsCache.isEmpty
                ? null
                : () => _clearARDiagnosticsCache(context, ref),
          ),
          if (storageReport.hasStorageWarnings)
            _StorageRepairSettingsTile(
              report: storageReport,
              onShowDetails: () => _showMediaStorageDiagnostics(
                context,
                storageReport,
              ),
              onRepair: () => _repairMediaStorage(context, ref),
            ),
          if (mediaMaintenancePlan.hasOrphanedMedia)
            _UnusedMediaSettingsTile(
              plan: mediaMaintenancePlan,
              onCleanUnused: () => _cleanUnusedMedia(context, ref),
            ),
          if (mediaUploadQueueMaintenancePlan.hasStaleEntries)
            _StaleUploadSettingsTile(
              plan: mediaUploadQueueMaintenancePlan,
              onCleanStale: () => _cleanStaleMediaUploads(context, ref),
            ),
          _ARSceneDiagnosticsBundleCacheSettingsTile(
            cache: arDiagnosticsBundleCache,
            onShowDetails: () => _showARSceneDiagnosticsBundleCache(
              context,
              ref,
              arDiagnosticsBundleCache,
            ),
            onClearCache: arDiagnosticsBundleCache.isEmpty
                ? null
                : () => _clearARSceneDiagnosticsBundleCache(context, ref),
          ),
          ListTile(
            key: const ValueKey('privacy_safety_tile'),
            leading: const Icon(Icons.security_outlined),
            title: const Text('Privacy and safety'),
            subtitle: Text(settings.privacySafetySummary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacySafetyScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearCache(
    BuildContext context,
    VoidCallback clearCachedMedia,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear cached media?'),
          content: const Text(
            'Offline previews will be downloaded again when needed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    clearCachedMedia();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Cached media cleared.')),
      );
  }

  void _cleanUnusedMedia(BuildContext context, WidgetRef ref) {
    final result =
        ref.read(anchorMediaMaintenanceServiceProvider).purgeUnreferencedMedia(
              memories: ref.read(nearbyAnchorsProvider),
              repository: ref.read(anchorMediaRepositoryProvider),
            );
    if (!context.mounted) {
      return;
    }

    final message =
        result.removedAny ? 'Unused media cleaned.' : 'No unused media found.';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _repairMediaStorage(BuildContext context, WidgetRef ref) {
    final result = ref.read(anchorMediaRepositoryProvider).repairStorage();
    if (!context.mounted) {
      return;
    }

    final message = result.repairedAny
        ? 'Media storage repaired: ${result.summaryLabel}.'
        : result.summaryLabel;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showMediaStorageDiagnostics(
    BuildContext context,
    AnchorMediaStorageReport report,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return _MediaStorageDiagnosticsSheet(report: report);
      },
    );
  }

  void _showARDiagnosticsCache(
    BuildContext context,
    WidgetRef ref,
    ARCaptureDiagnosticsMemoryCache cache,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _ARDiagnosticsCacheSheet(
          cache: cache,
          onClearCache: cache.isEmpty
              ? null
              : () {
                  _clearARDiagnosticsCache(context, ref);
                  Navigator.of(sheetContext).pop();
                },
        );
      },
    );
  }

  void _clearARDiagnosticsCache(BuildContext context, WidgetRef ref) {
    ref.read(captureSessionProvider.notifier).clearArDiagnosticsCache();
    ref.invalidate(arCaptureDiagnosticsCacheProvider);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('AR diagnostics cache cleared.')),
      );
  }

  void _showARSceneDiagnosticsBundleCache(
    BuildContext context,
    WidgetRef ref,
    ARSceneDiagnosticsExportBundleCache cache,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _ARSceneDiagnosticsBundleCacheSheet(
          cache: cache,
          onClearCache: cache.isEmpty
              ? null
              : () {
                  _clearARSceneDiagnosticsBundleCache(context, ref);
                  Navigator.of(sheetContext).pop();
                },
        );
      },
    );
  }

  void _clearARSceneDiagnosticsBundleCache(
    BuildContext context,
    WidgetRef ref,
  ) {
    ref.read(arSceneDiagnosticsExportBundleCacheStoreProvider).clearCache();
    ref.invalidate(arSceneDiagnosticsExportBundleCacheProvider);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('AR diagnostics bundles cleared.')),
      );
  }

  void _cleanStaleMediaUploads(BuildContext context, WidgetRef ref) {
    final removedCount = ref
        .read(anchorMediaUploadQueueProvider.notifier)
        .purgeStaleMedia(ref.read(nearbyAnchorsProvider));
    if (!context.mounted) {
      return;
    }

    final message = removedCount == 0
        ? 'No stale media uploads found.'
        : 'Stale media uploads cleaned.';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StorageSettingsTile extends StatelessWidget {
  const _StorageSettingsTile({
    required this.cachedMediaMb,
    required this.cachedMediaBytes,
    required this.storageReport,
    required this.onClearCache,
  });

  final int cachedMediaMb;
  final int cachedMediaBytes;
  final AnchorMediaStorageReport storageReport;
  final VoidCallback onClearCache;

  @override
  Widget build(BuildContext context) {
    final hasCache = cachedMediaMb > 0 || cachedMediaBytes > 0;

    return ListTile(
      leading: const Icon(Icons.storage_outlined),
      title: const Text('Storage'),
      subtitle: Text(_storageLabel),
      trailing: TextButton.icon(
        key: const ValueKey('clear_cached_media_button'),
        onPressed: hasCache ? onClearCache : null,
        icon: const Icon(Icons.delete_outline),
        label: const Text('Clear'),
      ),
    );
  }

  String get _storageLabel {
    if (!storageReport.hasStorageWarnings) {
      return _cacheLabel;
    }
    return '$_cacheLabel - ${storageReport.statusLabel}';
  }

  String get _cacheLabel {
    if (cachedMediaMb <= 0 && cachedMediaBytes <= 0) {
      return 'Cache is empty';
    }
    if (cachedMediaMb > 0 && cachedMediaBytes > 0) {
      return '$cachedMediaMb MB + ${_formatCacheBytes(cachedMediaBytes)} '
          'cached media';
    }
    if (cachedMediaMb > 0) {
      return '$cachedMediaMb MB cached media';
    }
    return '${_formatCacheBytes(cachedMediaBytes)} cached media';
  }
}

class _ARDiagnosticsCacheSettingsTile extends StatelessWidget {
  const _ARDiagnosticsCacheSettingsTile({
    required this.cache,
    required this.onShowDetails,
    required this.onClearCache,
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

class _ARSceneDiagnosticsBundleCacheSettingsTile extends StatelessWidget {
  const _ARSceneDiagnosticsBundleCacheSettingsTile({
    required this.cache,
    required this.onShowDetails,
    required this.onClearCache,
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
        '${_bundleSummaryLabel(latest)}';
  }
}

class _ARDiagnosticsCacheSheet extends StatefulWidget {
  const _ARDiagnosticsCacheSheet({
    required this.cache,
    required this.onClearCache,
  });

  final ARCaptureDiagnosticsMemoryCache cache;
  final VoidCallback? onClearCache;

  @override
  State<_ARDiagnosticsCacheSheet> createState() =>
      _ARDiagnosticsCacheSheetState();
}

class _ARDiagnosticsCacheSheetState extends State<_ARDiagnosticsCacheSheet> {
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
            _DiagnosticsValueRow(
              label: 'Cached captures',
              value: '${widget.cache.length}',
            ),
            _DiagnosticsValueRow(
              label: 'Syncable captures',
              value: '${widget.cache.syncableValues.length}',
            ),
            _DiagnosticsValueRow(
              label: 'Latest summary',
              value: latest?.summaryLabel ?? 'No AR diagnostics cached',
            ),
            _DiagnosticsValueRow(
              label: 'Timeline events',
              value: '${timeline.length}',
            ),
            _DiagnosticsValueRow(
              label: 'Timeline status',
              value: timeline.statusLabel,
            ),
            _DiagnosticsValueRow(
              label: 'Timeline latest',
              value: latestTimeline?.summaryLabel ?? 'No timeline events',
            ),
            if (timeline.warningCountLabel != null)
              _DiagnosticsValueRow(
                label: 'Timeline warnings',
                value: timeline.warningCountLabel!,
              ),
            if (latestWarning != null)
              _DiagnosticsValueRow(
                label: 'Timeline warning',
                value: latestWarning.detailLabel ?? latestWarning.summaryLabel,
              ),
            _DiagnosticsValueRow(
              label: 'Latest source',
              value: latest?.source ?? 'None',
            ),
            _DiagnosticsValueRow(
              label: 'Latest session',
              value: latest?.sessionId ?? 'Sessionless',
            ),
            _DiagnosticsValueRow(
              label: 'Latest capture',
              value: latest == null ? 'None' : _formatDiagnosticsTime(latest),
            ),
            _DiagnosticsValueRow(
              label: 'Report status',
              value: diagnosticsReport.statusLabel,
            ),
            _DiagnosticsValueRow(
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
              _DiagnosticsValueRow(
                label: 'Timeline matches',
                value: '${timelineQueryResult?.length ?? 0}',
              ),
              if (selectedTimelineFacet != null)
                _DiagnosticsValueRow(
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
                _DiagnosticsValueRow(
                  label: 'Match status',
                  value: timelineQueryResult.statusLabel,
                ),
              if (timelineQueryResult?.warningCountLabel != null)
                _DiagnosticsValueRow(
                  label: 'Match warnings',
                  value: timelineQueryResult!.warningCountLabel!,
                ),
              if (timelineMatchTypeLabels.isNotEmpty)
                _DiagnosticsValueRow(
                  label: 'Match types',
                  value: timelineMatchTypeLabels.join(', '),
                ),
              if (timelineMatchSeverityLabels.isNotEmpty)
                _DiagnosticsValueRow(
                  label: 'Match severities',
                  value: timelineMatchSeverityLabels.join(', '),
                ),
              if (timelineMatches.isEmpty)
                const _DiagnosticsValueRow(
                  label: 'Match',
                  value: 'No timeline events match',
                )
              else
                for (final event in timelineMatches.take(5))
                  _DiagnosticsValueRow(
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

class _ARSceneDiagnosticsBundleCacheSheet extends StatelessWidget {
  const _ARSceneDiagnosticsBundleCacheSheet({
    required this.cache,
    required this.onClearCache,
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
            _DiagnosticsValueRow(
              label: 'Cached bundles',
              value: '${cache.length}',
            ),
            _DiagnosticsValueRow(
              label: 'Latest summary',
              value: _bundleSummaryLabel(latest),
            ),
            _DiagnosticsValueRow(
              label: 'Latest export',
              value: latest == null
                  ? 'None'
                  : _formatBundleExportedAt(latest.exportedAt),
            ),
            _DiagnosticsValueRow(
              label: 'Latest session',
              value: latest?.sceneDiagnostics.sessionId ?? 'Sessionless',
            ),
            _DiagnosticsValueRow(
              label: 'Latest report',
              value: latest?.sessionDiagnosticsReport?.statusLabel ??
                  'No session report',
            ),
            _DiagnosticsValueRow(
              label: 'Latest runtime',
              value: latest?.runtimeDiagnosticsSummary.statusLabel ??
                  'No runtime diagnostics',
            ),
            if (latest?.runtimeDiagnosticsSummary.hasIssue ?? false)
              _DiagnosticsValueRow(
                label: 'Runtime detail',
                value: latest!.runtimeDiagnosticsSummary.detailLabel,
              ),
            if (latest?.runtimeDiagnosticsSummary.guidanceLabel != null)
              _DiagnosticsValueRow(
                label: 'Runtime action',
                value: latest!.runtimeDiagnosticsSummary.guidanceLabel!,
              ),
            if (latest?.sessionDiagnosticsReportDiff != null)
              _DiagnosticsValueRow(
                label: 'Latest trend',
                value: latest!.sessionDiagnosticsReportDiff!.statusLabel,
              ),
            _DiagnosticsValueRow(
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
                _DiagnosticsValueRow(
                  label: _recentBundleLabel(index),
                  value: _bundleHistoryLabel(recentBundles[index]),
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

class _StorageRepairSettingsTile extends StatelessWidget {
  const _StorageRepairSettingsTile({
    required this.report,
    required this.onShowDetails,
    required this.onRepair,
  });

  final AnchorMediaStorageReport report;
  final VoidCallback onShowDetails;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('repair_media_storage_tile'),
      leading: const Icon(Icons.healing_outlined),
      title: const Text('Media storage health'),
      subtitle: Text(report.statusLabel),
      onTap: onShowDetails,
      trailing: TextButton.icon(
        key: const ValueKey('repair_media_storage_button'),
        onPressed: onRepair,
        icon: const Icon(Icons.build_outlined),
        label: const Text('Repair'),
      ),
    );
  }
}

class _MediaStorageDiagnosticsSheet extends StatelessWidget {
  const _MediaStorageDiagnosticsSheet({required this.report});

  final AnchorMediaStorageReport report;

  @override
  Widget build(BuildContext context) {
    final payload = const JsonEncoder.withIndent('  ').convert(
      report.toJson(),
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Media storage diagnostics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('media_storage_diagnostics_close_button'),
                tooltip: 'Close diagnostics',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DiagnosticsValueRow(label: 'Status', value: report.statusLabel),
          _DiagnosticsValueRow(label: 'Backend', value: report.backendLabel),
          _DiagnosticsValueRow(
            label: 'Cached media',
            value: '${report.cachedMediaCount}',
          ),
          _DiagnosticsValueRow(
            label: 'Cached bytes',
            value: _formatCacheBytes(report.cachedByteLength),
          ),
          _DiagnosticsValueRow(
            label: 'Tracked blobs',
            value: '${report.trackedBlobFileCount}',
          ),
          _DiagnosticsValueRow(
            label: 'Orphaned blobs',
            value: '${report.orphanedBlobFileCount}',
          ),
          _DiagnosticsValueRow(
            label: 'Manifest',
            value: report.hasPersistentManifest ? 'Present' : 'Missing',
          ),
          _DiagnosticsValueRow(
            label: 'Backup manifest',
            value: report.hasBackupManifest ? 'Present' : 'Missing',
          ),
          _DiagnosticsValueRow(
            label: 'Temporary manifest',
            value: report.hasTemporaryManifest ? 'Present' : 'Missing',
          ),
          _DiagnosticsValueRow(
            label: 'Recovery manifest',
            value: report.hasInvalidManifest ? 'Present' : 'Missing',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Diagnostics payload',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('copy_media_storage_diagnostics_button'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: payload));
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Media storage diagnostics copied.'),
                      ),
                    );
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            payload,
            key: const ValueKey('media_storage_diagnostics_payload'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsValueRow extends StatelessWidget {
  const _DiagnosticsValueRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _UnusedMediaSettingsTile extends StatelessWidget {
  const _UnusedMediaSettingsTile({
    required this.plan,
    required this.onCleanUnused,
  });

  final AnchorMediaMaintenancePlan plan;
  final VoidCallback onCleanUnused;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('unused_media_cache_tile'),
      leading: const Icon(Icons.delete_sweep_outlined),
      title: const Text('Unused media'),
      subtitle: Text(
        '${plan.orphanedMediaLabel} - '
        '${_formatCacheBytes(plan.orphanedByteLength)}',
      ),
      trailing: TextButton.icon(
        key: const ValueKey('clean_unused_media_button'),
        onPressed: onCleanUnused,
        icon: const Icon(Icons.cleaning_services_outlined),
        label: const Text('Clean'),
      ),
    );
  }
}

class _StaleUploadSettingsTile extends StatelessWidget {
  const _StaleUploadSettingsTile({
    required this.plan,
    required this.onCleanStale,
  });

  final AnchorMediaUploadQueueMaintenancePlan plan;
  final VoidCallback onCleanStale;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('stale_media_upload_tile'),
      leading: const Icon(Icons.sync_problem_outlined),
      title: const Text('Stale media uploads'),
      subtitle: Text(plan.staleEntryLabel),
      trailing: TextButton.icon(
        key: const ValueKey('clean_stale_media_uploads_button'),
        onPressed: onCleanStale,
        icon: const Icon(Icons.playlist_remove_outlined),
        label: const Text('Clean'),
      ),
    );
  }
}

String _bundleSummaryLabel(ARSceneDiagnosticsExportBundle? bundle) {
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

String _bundleHistoryLabel(ARSceneDiagnosticsExportBundle bundle) {
  return '${_formatBundleExportedAt(bundle.exportedAt)} - '
      '${_bundleSummaryLabel(bundle)}';
}

String _recentBundleLabel(int index) {
  return switch (index) {
    0 => 'Latest',
    1 => 'Previous',
    _ => 'Earlier',
  };
}

String _formatBundleExportedAt(DateTime exportedAt) {
  final local = exportedAt.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _formatDiagnosticsTime(ARCaptureDiagnostics diagnostics) {
  final local = diagnostics.capturedAt.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatCacheBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }
  return '${(kib / 1024).toStringAsFixed(1)} MB';
}
