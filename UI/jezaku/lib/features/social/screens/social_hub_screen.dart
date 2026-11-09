import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/social/models/social_post.dart';
import 'package:jejaku/features/social/screens/comments_screen.dart';
import 'package:jejaku/features/social/screens/discover_screen.dart';
import 'package:jejaku/features/social/states/social_providers.dart';
import 'package:jejaku/features/social/widgets/social_post_card.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';

enum _FeedFilter { all, saved }

class SocialHubScreen extends StatelessWidget {
  const SocialHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Social'),
          actions: [
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.socialNotifications);
              },
            ),
            IconButton(
              tooltip: 'Messages',
              icon: const Icon(Icons.messenger_outline),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.socialMessages);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Feed'),
              Tab(text: 'Discover'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SocialFeedView(),
            DiscoverScreen(),
          ],
        ),
      ),
    );
  }
}

class _SocialFeedView extends ConsumerStatefulWidget {
  const _SocialFeedView();

  @override
  ConsumerState<_SocialFeedView> createState() => _SocialFeedViewState();
}

class _SocialFeedViewState extends ConsumerState<_SocialFeedView> {
  _FeedFilter _filter = _FeedFilter.all;

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(socialPostsProvider);
    final settings = ref.watch(appSettingsProvider);
    final unblockedPosts = posts
        .where((post) => !settings.isAccountBlocked(post.username))
        .toList();
    final visiblePosts = switch (_filter) {
      _FeedFilter.all => unblockedPosts,
      _FeedFilter.saved =>
        unblockedPosts.where((post) => post.isSaved).toList(),
    };
    final blockedPostsCount = posts.length - unblockedPosts.length;

    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 450));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<_FeedFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _FeedFilter.all,
                  label: Text('All'),
                ),
                ButtonSegment(
                  value: _FeedFilter.saved,
                  label: Text('Saved'),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) {
                setState(() => _filter = selection.first);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              _feedCountLabel(visiblePosts.length),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (blockedPostsCount > 0)
            _BlockedPostsNotice(
              hiddenCount: blockedPostsCount,
              onReview: () {
                Navigator.pushNamed(context, AppRoutes.privacySafety);
              },
            ),
          if (visiblePosts.isEmpty)
            _SavedPostsEmptyState(
              onShowAll: () => setState(() => _filter = _FeedFilter.all),
            )
          else
            for (final post in visiblePosts) _buildPostCard(context, post),
        ],
      ),
    );
  }

  String _feedCountLabel(int count) {
    final noun = count == 1 ? 'post' : 'posts';
    final scope = _filter == _FeedFilter.saved ? 'saved ' : '';
    return '$count $scope$noun';
  }

  Widget _buildPostCard(BuildContext context, SocialPost post) {
    return SocialPostCard(
      post: post,
      onComments: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommentsScreen(postId: post.id),
          ),
        );
      },
      onLike: () {
        ref.read(socialPostsProvider.notifier).toggleLike(post.id);
      },
      onOpenAr: () {
        Navigator.pushNamed(
          context,
          AppRoutes.arViewer,
          arguments: post.linkedMemoryId,
        );
      },
      onHide: () {
        ref.read(socialPostsProvider.notifier).hidePost(post.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${post.username} post hidden.')),
        );
      },
      onReport: () {
        ref.read(socialPostReportsProvider.notifier).reportPost(post);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${post.username} post reported.')),
        );
      },
      onSave: () {
        ref.read(socialPostsProvider.notifier).toggleSave(post.id);
      },
      onBlock: () {
        ref.read(appSettingsProvider.notifier).blockAccount(post.username);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${post.username} blocked.')),
        );
      },
    );
  }
}

class _BlockedPostsNotice extends StatelessWidget {
  const _BlockedPostsNotice({
    required this.hiddenCount,
    required this.onReview,
  });

  final int hiddenCount;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: const Icon(Icons.person_off_outlined),
          title: Text(
            '$hiddenCount ${hiddenCount == 1 ? 'post' : 'posts'} hidden from blocked accounts',
          ),
          trailing: TextButton(
            onPressed: onReview,
            child: const Text('Review'),
          ),
        ),
      ),
    );
  }
}

class _SavedPostsEmptyState extends StatelessWidget {
  const _SavedPostsEmptyState({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
      child: Column(
        children: [
          Icon(
            Icons.bookmark_border,
            color: colorScheme.outline,
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(
            'No saved posts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Save posts from the feed to build a quick return list.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onShowAll,
            icon: const Icon(Icons.clear_all),
            label: const Text('Show all'),
          ),
        ],
      ),
    );
  }
}
