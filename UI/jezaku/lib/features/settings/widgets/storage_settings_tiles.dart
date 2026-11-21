import 'package:jejaku/features/home/services/anchor_media_maintenance_service.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/sync/services/anchor_media_upload_queue_maintenance_service.dart';
import 'package:material_ui/material_ui.dart';

class StorageSettingsTile extends StatelessWidget {
  const StorageSettingsTile({
    required this.cachedMediaMb,
    required this.cachedMediaBytes,
    required this.storageReport,
    required this.onClearCache,
    super.key,
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
      return '$cachedMediaMb MB + ${formatCacheBytes(cachedMediaBytes)} '
          'cached media';
    }
    if (cachedMediaMb > 0) {
      return '$cachedMediaMb MB cached media';
    }
    return '${formatCacheBytes(cachedMediaBytes)} cached media';
  }
}

class StorageRepairSettingsTile extends StatelessWidget {
  const StorageRepairSettingsTile({
    required this.report,
    required this.onShowDetails,
    required this.onRepair,
    super.key,
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

class UnusedMediaSettingsTile extends StatelessWidget {
  const UnusedMediaSettingsTile({
    required this.plan,
    required this.onCleanUnused,
    super.key,
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
        '${formatCacheBytes(plan.orphanedByteLength)}',
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

class StaleUploadSettingsTile extends StatelessWidget {
  const StaleUploadSettingsTile({
    required this.plan,
    required this.onCleanStale,
    super.key,
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

