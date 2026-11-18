import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/profile/states/profile_providers.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

void main() {
  test('profile stats mirror the local memories, walls and sync queue', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final stats = container.read(profileStatsProvider);

    expect(stats.memories, container.read(nearbyAnchorsProvider).length);
    expect(stats.walls, container.read(arWallsProvider).length);
    expect(
      stats.pendingSync,
      container
          .read(nearbyAnchorsProvider)
          .where((memory) => memory.syncStatus != AnchorSyncStatus.synced)
          .length,
    );
  });
}
