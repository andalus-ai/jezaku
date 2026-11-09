import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/home/screens/memory_search_screen.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final journeyMemoryIds = [
      for (final step in ref.watch(spatialJourneyProvider)) step.memory.id,
    ];
    final topics = [
      const _DiscoverTopic(
        label: 'Nearby anchors',
        icon: Icons.near_me_outlined,
        countLabel: '12 items',
        routeName: AppRoutes.memorySearch,
      ),
      const _DiscoverTopic(
        label: 'Trending walls',
        icon: Icons.grid_view,
        countLabel: '19 items',
        routeName: AppRoutes.virtualWalls,
      ),
      _DiscoverTopic(
        label: 'Photo trails',
        icon: Icons.route,
        countLabel: journeyMemoryIds.length > 1
            ? '${journeyMemoryIds.length} stops'
            : 'Open AR',
        routeName: AppRoutes.arViewer,
        arguments: journeyMemoryIds.length > 1
            ? ARViewerArgs.trail(
                ARTrailSession.fromMemoryIds(
                  title: 'Discover photo trail',
                  memoryIds: journeyMemoryIds,
                  source: ARTrailSource.discover,
                ),
              )
            : null,
      ),
      if (settings.profileDiscoverable)
        const _DiscoverTopic(
          label: 'Friend activity',
          icon: Icons.group_outlined,
          countLabel: '33 items',
          routeName: AppRoutes.socialNotifications,
        ),
      const _DiscoverTopic(
        label: 'Public memories',
        icon: Icons.public,
        countLabel: '40 items',
        routeName: AppRoutes.memorySearch,
        arguments: MemorySearchArgs(initialFilter: 'Public'),
      ),
      const _DiscoverTopic(
        label: 'Saved places',
        icon: Icons.bookmark_border,
        countLabel: '47 items',
        routeName: AppRoutes.gallery,
      ),
    ];

    return CustomScrollView(
      slivers: [
        if (!settings.profileDiscoverable)
          SliverToBoxAdapter(
            child: _DiscoverPrivacyNotice(
              onReview: () {
                Navigator.pushNamed(context, AppRoutes.privacySafety);
              },
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            settings.profileDiscoverable ? 16 : 8,
            16,
            16,
          ),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.08,
            ),
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topic = topics[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pushNamed(
                    context,
                    topic.routeName,
                    arguments: topic.arguments,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(topic.icon, size: 32),
                        const Spacer(),
                        Text(
                          topic.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topic.countLabel,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DiscoverPrivacyNotice extends StatelessWidget {
  const _DiscoverPrivacyNotice({required this.onReview});

  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.visibility_off_outlined,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile hidden from friend discovery',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Friend activity is paused while discoverability is off.',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: onReview,
                      icon: const Icon(Icons.privacy_tip_outlined),
                      label: const Text('Review privacy'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverTopic {
  const _DiscoverTopic({
    required this.label,
    required this.icon,
    required this.countLabel,
    required this.routeName,
    this.arguments,
  });

  final String label;
  final IconData icon;
  final String countLabel;
  final String routeName;
  final Object? arguments;
}
