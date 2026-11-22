part of '../profile_screen.dart';

extension _ProfileTrailHistorySheet on ProfileScreen {
  void _showTrailHistorySheet(
    BuildContext context,
    WidgetRef ref,
    List<ARTrailProgress> completedTrails,
    ARTrailHistorySummary summary,
    Map<String, AnchorMemory> memoriesById,
    Set<String> wallLinkedMemoryIds,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Trail History',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (completedTrails.isNotEmpty)
                      IconButton(
                        key: const ValueKey('trail_history_clear_button'),
                        tooltip: 'Clear trail history',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _confirmClearTrailHistory(context, ref),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (completedTrails.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.route_outlined),
                    title: Text('No completed trails yet'),
                    subtitle: Text('Finished AR routes will appear here.'),
                  )
                else
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TrailHistorySummaryChips(summary: summary),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: completedTrails.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final trail = completedTrails[index];
                              return ListTile(
                                key: ValueKey(
                                  'trail_history_${trail.session.title}_$index',
                                ),
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.check_circle_outline),
                                title: Text(trail.session.title),
                                onTap: () => _showTrailDetailSheet(
                                  context,
                                  ref,
                                  trail,
                                  memoriesById,
                                  wallLinkedMemoryIds,
                                ),
                                subtitle: Text(
                                  '${trail.session.sourceLabel} - '
                                  '${trail.session.stopCountLabel} - '
                                  '${trail.progressLabel} - '
                                  '${trail.elapsedLabel}',
                                ),
                                trailing: IconButton(
                                  key: ValueKey(
                                    'trail_history_replay_${trail.session.title}_$index',
                                  ),
                                  tooltip: 'Replay trail',
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: () => _replayTrailFromHistory(
                                    context,
                                    trail,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _replayTrailFromHistory(
    BuildContext sheetContext,
    ARTrailProgress trail, {
    int popCount = 1,
  }) {
    final navigator = Navigator.of(sheetContext);
    for (var index = 0; index < popCount && navigator.canPop(); index++) {
      navigator.pop();
    }
    navigator.pushNamed(
      AppRoutes.arViewer,
      arguments: ARViewerArgs.trail(trail.session),
    );
  }

  Future<void> _confirmClearTrailHistory(
    BuildContext sheetContext,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear trail history?'),
          content: const Text(
            'Completed AR routes will be removed from this profile view.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('trail_history_confirm_clear_button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !sheetContext.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(sheetContext);
    final navigator = Navigator.of(sheetContext);
    ref.read(completedARTrailHistoryProvider.notifier).clear();
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Trail history cleared.')),
    );
  }

  Future<void> _confirmRemoveTrailFromHistory(
    BuildContext detailContext,
    WidgetRef ref,
    ARTrailProgress trail,
  ) async {
    final confirmed = await showDialog<bool>(
      context: detailContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove trail?'),
          content: Text(
            '"${trail.session.title}" will be removed from your trail history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('trail_detail_confirm_remove_button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !detailContext.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(detailContext);
    final navigator = Navigator.of(detailContext);
    ref.read(completedARTrailHistoryProvider.notifier).remove(trail);
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (navigator.canPop()) {
      navigator.pop();
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Trail removed from history.')),
    );
  }
}
