import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/sync/outbox/outbox_entry.dart';
import 'package:jejaku/features/sync/outbox/outbox_presentation.dart';
import 'package:jejaku/features/sync/states/frame_outbox_controller.dart';

/// Tells the person why a frame is not on the server yet and offers what they
/// can do about it: send now, try again, or stop sending. Draws nothing for a
/// frame that is not in the outbox, so it can sit in any list of frames.
class FrameOutboxStatusTile extends ConsumerWidget {
  const FrameOutboxStatusTile({
    required this.memoryId,
    this.now,
    super.key,
  });

  final String memoryId;

  /// The current time, for tests. Defaults to the clock.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(
      frameOutboxControllerProvider.select((s) => s.entryFor(memoryId)),
    );
    if (entry == null) {
      return const SizedBox.shrink();
    }
    final running = ref.watch(
      frameOutboxControllerProvider.select((s) => s.running),
    );
    final view = OutboxPresentation.describe(
      entry,
      running: running,
      now: (now ?? DateTime.now)().toUtc(),
    );
    final controller = ref.read(frameOutboxControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final refused = entry.hold == OutboxHold.rejected;

    return Semantics(
      container: true,
      label: '${view.title}. ${view.detail}',
      child: Container(
        key: ValueKey('outbox_status_$memoryId'),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: refused
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (running && entry.hold == null)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    refused ? Icons.error_outline : Icons.cloud_off_outlined,
                    size: 18,
                    color: refused
                        ? scheme.onErrorContainer
                        : scheme.onSurfaceVariant,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    view.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(view.detail, style: Theme.of(context).textTheme.bodySmall),
            if (view.canSendNow || view.canRetry || entry.hold != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (view.canSendNow)
                    TextButton.icon(
                      key: ValueKey('outbox_send_now_$memoryId'),
                      onPressed: () => controller.syncNow(),
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Send now'),
                    ),
                  if (view.canRetry)
                    TextButton.icon(
                      key: ValueKey('outbox_retry_$memoryId'),
                      onPressed: () => controller.retry(memoryId),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  if (entry.hold != null)
                    TextButton(
                      key: ValueKey('outbox_discard_$memoryId'),
                      onPressed: () => controller.discard(memoryId),
                      child: const Text('Stop sending'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
