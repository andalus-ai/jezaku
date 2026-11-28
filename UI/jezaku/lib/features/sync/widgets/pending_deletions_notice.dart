import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/sync/states/frame_outbox_controller.dart';
import 'package:jejaku/features/sync/states/frame_outbox_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Tells the person that frames they deleted are not removed from the server
/// yet (they were deleted offline, or the sign-in is gone) and lets them try
/// again. Draws nothing when no deletion is waiting, so it can sit above any
/// state of the sync queue, including the empty one.
class PendingDeletionsNotice extends ConsumerStatefulWidget {
  const PendingDeletionsNotice({super.key});

  @override
  ConsumerState<PendingDeletionsNotice> createState() =>
      _PendingDeletionsNoticeState();
}

class _PendingDeletionsNoticeState
    extends ConsumerState<PendingDeletionsNotice> {
  bool _trying = false;

  static String titleFor(int count) => count == 1
      ? '1 deleted frame is still to be removed from the server'
      : '$count deleted frames are still to be removed from the server';

  static const detail = 'They are already gone from this device. They are '
      'removed from the server when you are online and signed in, and this '
      'is tried again automatically.';

  Future<void> _tryNow() async {
    setState(() => _trying = true);
    final before = ref.read(pendingDeletionCountProvider);
    final removed =
        await ref.read(frameOutboxControllerProvider.notifier).syncDeletions();
    if (!mounted) {
      return;
    }
    setState(() => _trying = false);
    final stillWaiting = ref.read(pendingDeletionCountProvider);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            removed == 0 && stillWaiting >= before
                ? 'Could not reach the server. Still waiting; this is tried '
                    'again automatically.'
                : removed == 1
                    ? '1 deleted frame removed from the server.'
                    : '$removed deleted frames removed from the server.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(pendingDeletionCountProvider);
    if (count == 0) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final title = titleFor(count);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Semantics(
        container: true,
        label: '$title. $detail',
        child: Container(
          key: const ValueKey('pending_deletions_notice'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_trying)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.delete_sweep_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('pending_deletions_try_now'),
                  onPressed: _trying ? null : _tryNow,
                  child: const Text('Try now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
