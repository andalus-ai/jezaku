import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/sample_data_provider.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

ProviderContainer _container({
  required bool samples,
  AnchorMemoryStore? store,
}) {
  final container = ProviderContainer(
    overrides: [
      sampleDataEnabledProvider.overrideWithValue(samples),
      if (store != null) anchorMemoryStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('samples are enabled by default in debug and test builds', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(sampleDataEnabledProvider), isTrue);
    expect(container.read(nearbyAnchorsProvider), isNotEmpty);
    expect(container.read(arWallsProvider), isNotEmpty);
  });

  test('disabling samples starts with empty anchors and walls', () {
    final container = _container(samples: false);

    expect(container.read(nearbyAnchorsProvider), isEmpty);
    expect(container.read(arWallsProvider), isEmpty);
  });

  test('captures still work and persist when samples are disabled', () {
    final store = InMemoryAnchorMemoryStore();
    final container = _container(samples: false, store: store);

    final memory = container
        .read(nearbyAnchorsProvider.notifier)
        .addCapturedMemory(
          caption: 'First real memory',
          radiusMeters: 12,
          isPrivate: false,
          capturedAt: DateTime(2026, 6, 1, 9),
        );

    expect(
      container.read(nearbyAnchorsProvider).map((m) => m.id),
      [memory.id],
    );
    expect(store.loadCapturedMemories().map((m) => m.id), [memory.id]);

    final restarted = _container(samples: false, store: store);
    expect(
      restarted.read(nearbyAnchorsProvider).map((m) => m.caption),
      ['First real memory'],
    );
  });

  test('stored memories are kept alongside samples when enabled', () {
    final store = InMemoryAnchorMemoryStore();
    final first = _container(samples: false, store: store);
    first.read(nearbyAnchorsProvider.notifier).addCapturedMemory(
          caption: 'Kept memory',
          radiusMeters: 12,
          isPrivate: false,
          capturedAt: DateTime(2026, 6, 1, 9),
        );

    final withSamples = _container(samples: true, store: store);
    final captions =
        withSamples.read(nearbyAnchorsProvider).map((m) => m.caption);
    expect(captions, contains('Kept memory'));
    expect(captions.length, greaterThan(1));
  });
}
