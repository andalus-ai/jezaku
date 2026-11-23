import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_resolver.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/widgets/memory_preview.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:jejaku/features/social/states/social_comment_provider.dart';
import 'package:jejaku/features/social/widgets/comment_composer.dart';
import 'package:jejaku/features/social/widgets/comment_tile.dart';
import 'package:material_ui/material_ui.dart';

/// The photo page of a hung frame: what friends see when they open the frame
/// from AR. Shows the photo, its caption and place, and an Instagram-style
/// comment thread. Back returns to wherever it was opened from, typically the
/// AR viewer.
class MemoryPhotoScreen extends ConsumerWidget {
  const MemoryPhotoScreen({super.key, required this.memoryId});

  final String memoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(nearbyAnchorsProvider);
    final memory = _findMemory(memories);

    if (memory == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Photo')),
        body: const Center(child: Text('This frame is no longer available.')),
      );
    }

    final resolvedMedia = ref.watch(anchorResolvedMediaProvider(memory));
    final settings = ref.watch(appSettingsProvider);
    final visibleComments = ref
        .watch(postCommentsProvider(memory.id))
        .where((comment) => !settings.isAccountBlocked(comment.username))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo'),
        actions: [
          IconButton(
            key: const ValueKey('memory_photo_details_button'),
            tooltip: 'Frame details',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.memoryDetails,
              arguments: memory.id,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MemoryPreview(memory: memory, resolvedMedia: resolvedMedia),
                const SizedBox(height: 12),
                Text(
                  memory.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (memory.caption.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(memory.caption),
                ],
                const SizedBox(height: 8),
                _PhotoMetaRow(memory: memory),
                const Divider(height: 32),
                _CommentsHeading(
                  count: visibleComments.length,
                  enabled: memory.allowComments,
                ),
                const SizedBox(height: 12),
                if (!memory.allowComments)
                  const _CommentsState(
                    key: ValueKey('memory_photo_comments_off'),
                    icon: Icons.comments_disabled_outlined,
                    message: 'Comments are turned off for this frame.',
                  )
                else if (visibleComments.isEmpty)
                  const _CommentsState(
                    key: ValueKey('memory_photo_comments_empty'),
                    icon: Icons.mode_comment_outlined,
                    message: 'No comments yet. Be the first to say something.',
                  )
                else
                  for (final comment in visibleComments)
                    CommentTile(comment: comment),
              ],
            ),
          ),
          if (memory.allowComments)
            CommentComposer(
              hintText: 'Add a comment as a friend',
              onSubmit: (text) => ref
                  .read(socialCommentsProvider.notifier)
                  .addComment(postId: memory.id, text: text),
            ),
        ],
      ),
    );
  }

  AnchorMemory? _findMemory(List<AnchorMemory> memories) {
    for (final memory in memories) {
      if (memory.id == memoryId) {
        return memory;
      }
    }
    return null;
  }
}

class _PhotoMetaRow extends StatelessWidget {
  const _PhotoMetaRow({required this.memory});

  final AnchorMemory memory;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    final style = TextStyle(color: color, fontSize: 13);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        _MetaItem(
          icon: Icons.place_outlined,
          label: memory.locationLabel,
          style: style,
        ),
        _MetaItem(
          icon: Icons.schedule,
          label: memory.capturedAgo,
          style: style,
        ),
        _MetaItem(
          icon: memory.isPrivate ? Icons.lock_outline : Icons.people_outline,
          label: memory.isPrivate ? 'Private' : 'Friends',
          style: style,
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.style,
  });

  final IconData icon;
  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: style.color),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }
}

class _CommentsHeading extends StatelessWidget {
  const _CommentsHeading({required this.count, required this.enabled});

  final int count;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        enabled && count > 0 ? 'Comments ($count)' : 'Comments',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _CommentsState extends StatelessWidget {
  const _CommentsState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
