import 'dart:convert';

import 'package:ar_model_cache/ar_model_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ARModelCacheSettingsTile extends StatelessWidget {
  const ARModelCacheSettingsTile({
    required this.stats,
    required this.entries,
    this.integrity,
    this.onRepairIntegrity,
    this.onRepairManifests,
    super.key,
  });

  final AsyncValue<ARModelAssetCacheStats> stats;
  final AsyncValue<List<ARModelAssetCacheEntry>> entries;
  final AsyncValue<ARModelAssetCacheIntegrityReport>? integrity;
  final Future<ARModelAssetCacheIntegrityRepairResult> Function()?
      onRepairIntegrity;
  final Future<ARModelAssetCacheRepairResult> Function()? onRepairManifests;

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowTile) {
      return const SizedBox.shrink();
    }

    final cachedEntries = _entriesOrNull(entries);
    final hasEntries = cachedEntries != null && cachedEntries.isNotEmpty;

    return ListTile(
      key: const ValueKey('ar_model_cache_tile'),
      leading: const Icon(Icons.view_in_ar_outlined),
      title: const Text('3D model cache'),
      subtitle: Text(_summaryLabel),
      trailing: hasEntries ? const Icon(Icons.chevron_right) : null,
      onTap: hasEntries
          ? () => _showModelCacheDetails(context, cachedEntries)
          : null,
    );
  }

  bool get _shouldShowTile {
    final cachedEntries = _entriesOrNull(entries);
    if (cachedEntries != null && cachedEntries.isNotEmpty) {
      return true;
    }
    return stats.when<bool>(
      data: (cacheStats) => !cacheStats.isEmpty,
      error: (error, stackTrace) => false,
      loading: () => false,
    );
  }

  String get _summaryLabel {
    return entries.when<String>(
      data: _loadedSummaryLabel,
      error: (error, stackTrace) {
        return stats.when<String>(
          data: (cacheStats) {
            if (cacheStats.isEmpty) {
              return '3D model cache unavailable';
            }
            return '${_modelCountLabel(cacheStats.entryCount)} - '
                '${cacheStats.sizeLabel}, details unavailable';
          },
          error: (error, stackTrace) => '3D model cache unavailable',
          loading: () => '3D model cache unavailable',
        );
      },
      loading: () {
        return stats.when<String>(
          data: (cacheStats) {
            if (cacheStats.isEmpty) {
              return 'Checking 3D model cache...';
            }
            return '${_modelCountLabel(cacheStats.entryCount)} - '
                '${cacheStats.sizeLabel}, loading details';
          },
          error: (error, stackTrace) => 'Checking 3D model cache...',
          loading: () => 'Checking 3D model cache...',
        );
      },
    );
  }

  String _loadedSummaryLabel(List<ARModelAssetCacheEntry> cachedEntries) {
    if (cachedEntries.isEmpty) {
      return stats.when<String>(
        data: (cacheStats) {
          if (cacheStats.isEmpty) {
            return 'No cached 3D models';
          }
          return '${_modelCountLabel(cacheStats.entryCount)} - '
              '${cacheStats.sizeLabel}, details unavailable';
        },
        error: (error, stackTrace) => 'No cached 3D models',
        loading: () => 'Checking 3D model cache...',
      );
    }
    final latest = _latestEntry(cachedEntries);
    final attentionLabel = _integrityAttentionLabel(integrity) ??
        _manifestAttentionLabel(cachedEntries);
    return '${_modelCountLabel(cachedEntries.length)} - '
        '${_formatCacheBytes(_totalByteLength(cachedEntries))}, '
        'last used ${_formatModelCacheDate(latest.lastUsedAt)}'
        '${attentionLabel == null ? '' : ' - $attentionLabel'}';
  }

  void _showModelCacheDetails(
    BuildContext context,
    List<ARModelAssetCacheEntry> cachedEntries,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return ARModelCacheDetailsSheet(
          entries: cachedEntries,
          integrityReport: _integrityReportOrNull(integrity),
          onRepairIntegrity: onRepairIntegrity,
          onRepairManifests: onRepairManifests,
        );
      },
    );
  }
}

class ARModelCacheDetailsSheet extends StatelessWidget {
  const ARModelCacheDetailsSheet({
    required this.entries,
    this.integrityReport,
    this.onRepairIntegrity,
    this.onRepairManifests,
    super.key,
  });

  final List<ARModelAssetCacheEntry> entries;
  final ARModelAssetCacheIntegrityReport? integrityReport;
  final Future<ARModelAssetCacheIntegrityRepairResult> Function()?
      onRepairIntegrity;
  final Future<ARModelAssetCacheRepairResult> Function()? onRepairManifests;

  @override
  Widget build(BuildContext context) {
    final latest = _latestEntry(entries);
    final visibleEntries = entries.take(20).toList(growable: false);
    final payload = _modelCachePayload(
      entries,
      integrityReport: integrityReport,
    );
    final missingManifestCount = _missingManifestCount(entries);
    final hasIntegrityIssues =
        integrityReport != null && !integrityReport!.isHealthy;
    final canRepairIntegrity = hasIntegrityIssues && onRepairIntegrity != null;
    final canRepairManifests = !canRepairIntegrity &&
        missingManifestCount > 0 &&
        onRepairManifests != null;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '3D model cache',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const ValueKey('ar_model_cache_details_close_button'),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ModelCacheDetailRow(
            label: 'Cached models',
            value: '${entries.length}',
          ),
          _ModelCacheDetailRow(
            label: 'Cached bytes',
            value: _formatCacheBytes(_totalByteLength(entries)),
          ),
          _ModelCacheDetailRow(
            label: 'Latest use',
            value: _formatModelCacheDate(latest.lastUsedAt),
          ),
          _ModelCacheDetailRow(
            label: 'Manifests',
            value: _manifestHealthLabel(entries),
          ),
          if (integrityReport != null)
            _ModelCacheDetailRow(
              label: 'Integrity',
              value: integrityReport!.summaryLabel,
            ),
          if (canRepairIntegrity || canRepairManifests) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: canRepairIntegrity
                  ? TextButton.icon(
                      key: const ValueKey(
                        'repair_ar_model_cache_integrity_button',
                      ),
                      onPressed: () => _repairIntegrity(context),
                      icon: const Icon(Icons.build_circle_outlined),
                      label: const Text('Repair cache'),
                    )
                  : TextButton.icon(
                      key: const ValueKey(
                        'repair_ar_model_cache_manifests_button',
                      ),
                      onPressed: () => _repairManifests(context),
                      icon: const Icon(Icons.build_circle_outlined),
                      label: const Text('Repair manifests'),
                    ),
            ),
          ],
          const Divider(height: 28),
          for (final entry in visibleEntries)
            _ModelCacheEntryTile(entry: entry),
          if (visibleEntries.length < entries.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Showing ${visibleEntries.length} of ${entries.length} '
                'cached models',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
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
                key: const ValueKey('copy_ar_model_cache_button'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: payload));
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('3D model cache copied.'),
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
            key: const ValueKey('ar_model_cache_payload'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _repairManifests(BuildContext context) async {
    final repair = onRepairManifests;
    if (repair == null) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result = await repair();
    if (!context.mounted) {
      return;
    }
    navigator.pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(result.summaryLabel)),
      );
  }

  Future<void> _repairIntegrity(BuildContext context) async {
    final repair = onRepairIntegrity;
    if (repair == null) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result = await repair();
    if (!context.mounted) {
      return;
    }
    navigator.pop();
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(result.summaryLabel)),
      );
  }
}

class _ModelCacheEntryTile extends StatelessWidget {
  const _ModelCacheEntryTile({required this.entry});

  final ARModelAssetCacheEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('ar_model_cache_entry_${entry.cacheKey}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.view_in_ar_outlined),
      title: Text(
        _entryTitle(entry),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _entrySubtitle(entry),
      ),
    );
  }
}

class _ModelCacheDetailRow extends StatelessWidget {
  const _ModelCacheDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

List<ARModelAssetCacheEntry>? _entriesOrNull(
  AsyncValue<List<ARModelAssetCacheEntry>> value,
) {
  return value.when<List<ARModelAssetCacheEntry>?>(
    data: (entries) => entries,
    error: (error, stackTrace) => null,
    loading: () => null,
  );
}

ARModelAssetCacheIntegrityReport? _integrityReportOrNull(
  AsyncValue<ARModelAssetCacheIntegrityReport>? value,
) {
  return value?.when<ARModelAssetCacheIntegrityReport?>(
    data: (report) => report,
    error: (error, stackTrace) => null,
    loading: () => null,
  );
}

ARModelAssetCacheEntry _latestEntry(List<ARModelAssetCacheEntry> entries) {
  return entries.reduce((latest, entry) {
    return entry.lastUsedAt.isAfter(latest.lastUsedAt) ? entry : latest;
  });
}

int _totalByteLength(List<ARModelAssetCacheEntry> entries) {
  return entries.fold<int>(
    0,
    (total, entry) => total + entry.byteLength,
  );
}

String _modelCachePayload(
  List<ARModelAssetCacheEntry> entries, {
  ARModelAssetCacheIntegrityReport? integrityReport,
}) {
  final latest = _latestEntry(entries);
  return const JsonEncoder.withIndent('  ').convert(
    <String, Object?>{
      'schemaVersion': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'entryCount': entries.length,
      'byteLength': _totalByteLength(entries),
      'latestUsedAt': latest.lastUsedAt.toUtc().toIso8601String(),
      'entries': [
        for (final entry in entries) entry.toMetadata(),
      ],
      'integrity': integrityReport?.toMetadata(),
    },
  );
}

String _entrySubtitle(ARModelAssetCacheEntry entry) {
  final labels = <String>[
    _formatCacheBytes(entry.byteLength),
    _formatModelFormat(entry.format),
    if (!entry.hasManifest) 'missing manifest',
    'last used ${_formatModelCacheDate(entry.lastUsedAt)}',
  ];
  return labels.join(' - ');
}

String _manifestHealthLabel(List<ARModelAssetCacheEntry> entries) {
  final missingCount = _missingManifestCount(entries);
  if (missingCount == 0) {
    return 'All entries indexed';
  }
  return _missingManifestLabel(missingCount);
}

String? _manifestAttentionLabel(List<ARModelAssetCacheEntry> entries) {
  final missingCount = _missingManifestCount(entries);
  if (missingCount == 0) {
    return null;
  }
  return _missingManifestLabel(missingCount);
}

String? _integrityAttentionLabel(
  AsyncValue<ARModelAssetCacheIntegrityReport>? value,
) {
  final report = _integrityReportOrNull(value);
  if (report == null || report.isHealthy) {
    return null;
  }
  return report.summaryLabel;
}

int _missingManifestCount(List<ARModelAssetCacheEntry> entries) {
  return entries.where((entry) => !entry.hasManifest).length;
}

String _missingManifestLabel(int count) {
  return count == 1 ? '1 missing manifest' : '$count missing manifests';
}

String _modelCountLabel(int count) {
  return count == 1 ? '1 cached 3D model' : '$count cached 3D models';
}

String _entryTitle(ARModelAssetCacheEntry entry) {
  final sourcePath = entry.sourcePath;
  if (sourcePath != null && sourcePath.trim().isNotEmpty) {
    return _basename(sourcePath);
  }
  return _basename(entry.path);
}

String _basename(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final segments = normalized.split('/');
  return segments.isEmpty ? path : segments.last;
}

String _formatModelFormat(String? format) {
  final normalized = format?.trim();
  if (normalized == null || normalized.isEmpty) {
    return 'MODEL';
  }
  return normalized.toUpperCase();
}

String _formatModelCacheDate(DateTime dateTime) {
  final local = dateTime.toLocal();
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
