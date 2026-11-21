import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/settings/services/settings_diagnostics_formatters.dart';
import 'package:jejaku/features/settings/widgets/diagnostics_value_row.dart';
import 'package:material_ui/material_ui.dart';

class MediaStorageDiagnosticsSheet extends StatelessWidget {
  const MediaStorageDiagnosticsSheet({required this.report, super.key});

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
          DiagnosticsValueRow(label: 'Status', value: report.statusLabel),
          DiagnosticsValueRow(label: 'Backend', value: report.backendLabel),
          DiagnosticsValueRow(
            label: 'Cached media',
            value: '${report.cachedMediaCount}',
          ),
          DiagnosticsValueRow(
            label: 'Cached bytes',
            value: formatCacheBytes(report.cachedByteLength),
          ),
          DiagnosticsValueRow(
            label: 'Tracked blobs',
            value: '${report.trackedBlobFileCount}',
          ),
          DiagnosticsValueRow(
            label: 'Orphaned blobs',
            value: '${report.orphanedBlobFileCount}',
          ),
          DiagnosticsValueRow(
            label: 'Manifest',
            value: report.hasPersistentManifest ? 'Present' : 'Missing',
          ),
          DiagnosticsValueRow(
            label: 'Backup manifest',
            value: report.hasBackupManifest ? 'Present' : 'Missing',
          ),
          DiagnosticsValueRow(
            label: 'Temporary manifest',
            value: report.hasTemporaryManifest ? 'Present' : 'Missing',
          ),
          DiagnosticsValueRow(
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

