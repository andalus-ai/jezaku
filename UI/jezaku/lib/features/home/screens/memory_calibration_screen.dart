import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';

class MemoryCalibrationScreen extends ConsumerStatefulWidget {
  const MemoryCalibrationScreen({
    super.key,
    required this.memoryId,
  });

  final String memoryId;

  @override
  ConsumerState<MemoryCalibrationScreen> createState() =>
      _MemoryCalibrationScreenState();
}

class _MemoryCalibrationScreenState
    extends ConsumerState<MemoryCalibrationScreen> {
  double _eastMeters = 0;
  double _northMeters = 0;
  double _upMeters = 0;
  bool _isInitialized = false;

  @override
  Widget build(BuildContext context) {
    final memory = _findMemory(ref.watch(nearbyAnchorsProvider));

    if (memory == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Calibrate Anchor')),
        body: const Center(child: Text('Memory not found')),
      );
    }

    if (!_isInitialized) {
      final metadata = memory.captureMetadata;
      _eastMeters = metadata.correctionEastMeters;
      _northMeters = metadata.correctionNorthMeters;
      _upMeters = metadata.correctionUpMeters;
      _isInitialized = true;
    }
    final suggestion = memory.captureMetadata.suggestedCorrection;

    return Scaffold(
      appBar: AppBar(title: const Text('Calibrate Anchor')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 144),
        children: [
          Text(
            memory.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Nudge the AR frame until it lines up with the real capture point.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (memory.needsCalibrationReview) ...[
            _CalibrationIssueBanner(metadata: memory.captureMetadata),
            const SizedBox(height: 16),
          ],
          _CalibrationSuggestionPanel(suggestion: suggestion),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _applySuggestedCorrection(suggestion),
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Apply Suggested Correction'),
          ),
          const SizedBox(height: 16),
          _CalibrationPreview(
            eastMeters: _eastMeters,
            northMeters: _northMeters,
            upMeters: _upMeters,
          ),
          const SizedBox(height: 16),
          _OffsetSlider(
            label: 'East / West',
            value: _eastMeters,
            negativeLabel: 'West',
            positiveLabel: 'East',
            onChanged: (value) => setState(() => _eastMeters = value),
          ),
          _OffsetSlider(
            label: 'North / South',
            value: _northMeters,
            negativeLabel: 'South',
            positiveLabel: 'North',
            onChanged: (value) => setState(() => _northMeters = value),
          ),
          _OffsetSlider(
            label: 'Up / Down',
            value: _upMeters,
            negativeLabel: 'Down',
            positiveLabel: 'Up',
            onChanged: (value) => setState(() => _upMeters = value),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset Correction'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _save(memory, previewInAr: true),
                icon: const Icon(Icons.view_in_ar),
                label: const Text('Save & Preview AR'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _save(memory),
                icon: const Icon(Icons.check),
                label: const Text('Save Calibration'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AnchorMemory? _findMemory(List<AnchorMemory> memories) {
    for (final memory in memories) {
      if (memory.id == widget.memoryId) {
        return memory;
      }
    }
    return null;
  }

  void _reset() {
    setState(() {
      _eastMeters = 0;
      _northMeters = 0;
      _upMeters = 0;
    });
  }

  void _applySuggestedCorrection(AnchorCalibrationSuggestion suggestion) {
    setState(() {
      _eastMeters = suggestion.eastMeters;
      _northMeters = suggestion.northMeters;
      _upMeters = suggestion.upMeters;
    });
  }

  void _save(AnchorMemory memory, {bool previewInAr = false}) {
    ref.read(nearbyAnchorsProvider.notifier).updateManualCorrection(
          memoryId: memory.id,
          eastMeters: _eastMeters,
          northMeters: _northMeters,
          upMeters: _upMeters,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Anchor calibrated. Metadata update queued.'),
      ),
    );
    if (previewInAr) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.arViewer,
        arguments: memory.id,
      );
      return;
    }
    Navigator.pop(context);
  }
}

class _CalibrationIssueBanner extends StatelessWidget {
  const _CalibrationIssueBanner({required this.metadata});

  final AnchorCaptureMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  size: 18,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Placement needs calibration',
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              metadata.calibrationReasonLabel,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 4),
            Text(
              metadata.calibrationGuidanceLabel,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationSuggestionPanel extends StatelessWidget {
  const _CalibrationSuggestionPanel({required this.suggestion});

  final AnchorCalibrationSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_fix_high,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion.description,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion.offsetLabel,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationPreview extends StatelessWidget {
  const _CalibrationPreview({
    required this.eastMeters,
    required this.northMeters,
    required this.upMeters,
  });

  final double eastMeters;
  final double northMeters;
  final double upMeters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.open_with, color: colorScheme.primary, size: 42),
            const SizedBox(height: 12),
            Text(
              'Manual Correction',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                Chip(label: Text('E ${eastMeters.toStringAsFixed(1)} m')),
                Chip(label: Text('N ${northMeters.toStringAsFixed(1)} m')),
                Chip(label: Text('U ${upMeters.toStringAsFixed(1)} m')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OffsetSlider extends StatelessWidget {
  const _OffsetSlider({
    required this.label,
    required this.value,
    required this.negativeLabel,
    required this.positiveLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String negativeLabel;
  final String positiveLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${value.toStringAsFixed(1)} m'),
              ],
            ),
            Slider(
              min: -5,
              max: 5,
              divisions: 20,
              value: value,
              label: '${value.toStringAsFixed(1)} m',
              onChanged: onChanged,
            ),
            Row(
              children: [
                Text(negativeLabel),
                const Spacer(),
                Text(positiveLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
