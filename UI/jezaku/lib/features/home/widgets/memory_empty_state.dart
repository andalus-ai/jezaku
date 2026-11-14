import 'package:flutter/material.dart';

/// Empty state shared by the home list and the gallery.
///
/// With no memories at all it invites the first capture. When memories exist
/// but the current filter hides them, it offers a way back instead.
class MemoryEmptyState extends StatelessWidget {
  const MemoryEmptyState({
    required this.hasAnyMemories,
    required this.onCapture,
    required this.onResetFilter,
    super.key,
  });

  final bool hasAnyMemories;
  final VoidCallback onCapture;
  final VoidCallback onResetFilter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final title =
        hasAnyMemories ? 'Nothing matches this filter' : 'No memories yet';
    final message = hasAnyMemories
        ? 'Try another filter to see your other memories.'
        : 'Capture a photo or video where you are. It becomes a memory '
            'pinned to this place.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          container: true,
          label: '$title. $message',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  hasAnyMemories
                      ? Icons.filter_alt_off_outlined
                      : Icons.add_location_alt_outlined,
                  color: colorScheme.outline,
                  size: 48,
                ),
              ),
              const SizedBox(height: 12),
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (hasAnyMemories)
                OutlinedButton.icon(
                  onPressed: onResetFilter,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Show all'),
                )
              else
                FilledButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Capture a memory'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
