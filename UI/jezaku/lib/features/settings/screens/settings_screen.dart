import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
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
import 'package:jejaku/features/settings/widgets/ar_diagnostics_cache_widgets.dart';
import 'package:jejaku/features/settings/widgets/ar_model_cache_settings_tile.dart';
import 'package:jejaku/features/settings/widgets/ar_scene_diagnostics_bundle_cache_widgets.dart';
import 'package:jejaku/features/settings/widgets/media_storage_diagnostics_sheet.dart';
import 'package:jejaku/features/settings/widgets/settings_section_header.dart';
import 'package:jejaku/features/settings/widgets/storage_settings_tiles.dart';
import 'package:jejaku/features/sync/services/anchor_media_upload_queue_maintenance_service.dart';
import 'package:jejaku/features/sync/states/anchor_media_upload_queue_provider.dart';
import 'package:material_ui/material_ui.dart';

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
          const SettingsSectionHeader(title: 'Notifications'),
          SwitchListTile(
            key: const ValueKey('nearby_notifications_switch'),
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Nearby notifications'),
            subtitle: const Text('Alert when friends leave anchors nearby'),
            value: settings.nearbyNotifications,
            onChanged: controller.setNearbyNotifications,
          ),
          const Divider(),
          const SettingsSectionHeader(title: 'Privacy and anchoring'),
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
          const SettingsSectionHeader(title: 'Family safety'),
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
          const SettingsSectionHeader(title: 'Storage and diagnostics'),
          StorageSettingsTile(
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
          ARDiagnosticsCacheSettingsTile(
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
            StorageRepairSettingsTile(
              report: storageReport,
              onShowDetails: () => _showMediaStorageDiagnostics(
                context,
                storageReport,
              ),
              onRepair: () => _repairMediaStorage(context, ref),
            ),
          if (mediaMaintenancePlan.hasOrphanedMedia)
            UnusedMediaSettingsTile(
              plan: mediaMaintenancePlan,
              onCleanUnused: () => _cleanUnusedMedia(context, ref),
            ),
          if (mediaUploadQueueMaintenancePlan.hasStaleEntries)
            StaleUploadSettingsTile(
              plan: mediaUploadQueueMaintenancePlan,
              onCleanStale: () => _cleanStaleMediaUploads(context, ref),
            ),
          ARSceneDiagnosticsBundleCacheSettingsTile(
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
          const Divider(),
          const SettingsSectionHeader(title: 'About'),
          ListTile(
            key: const ValueKey('legal_tile'),
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms and policies'),
            subtitle: const Text(
              'Terms of use, privacy policy, community guidelines',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.legal),
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
        return MediaStorageDiagnosticsSheet(report: report);
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
        return ARDiagnosticsCacheSheet(
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
        return ARSceneDiagnosticsBundleCacheSheet(
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
