import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';

class ModerationQueueScreen extends ConsumerWidget {
  const ModerationQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flaggedMemories = ref.watch(moderationQueueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Moderation Queue')),
      body: flaggedMemories.isEmpty
          ? const _EmptyModerationState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: flaggedMemories.length,
              itemBuilder: (context, index) {
                return _ModerationCard(memory: flaggedMemories[index]);
              },
            ),
    );
  }
}

class _ModerationCard extends ConsumerWidget {
  const _ModerationCard({required this.memory});

  final AnchorMemory memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.report_outlined, color: colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    memory.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(memory.reportCountLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(memory.reportReason ?? 'No reason provided'),
            const SizedBox(height: 8),
            Text(
              memory.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.memoryDetails,
                      arguments: memory.id,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(nearbyAnchorsProvider.notifier)
                          .approveMemory(memory.id);
                    },
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(nearbyAnchorsProvider.notifier)
                          .hideMemory(memory.id);
                    },
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('Hide'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyModerationState extends StatelessWidget {
  const _EmptyModerationState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined,
                color: colorScheme.primary, size: 56),
            const SizedBox(height: 12),
            Text(
              'No reports pending',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Reported public memories and AR anchors will appear here for review.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
