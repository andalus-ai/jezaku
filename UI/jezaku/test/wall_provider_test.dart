import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/models/wall_trail_preview.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';

void main() {
  test('wall filters expose nearby trending public and group walls', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container
          .read(filteredARWallsProvider(ARWallFilter.nearby))
          .map((wall) => wall.title),
      ['Class Reunion Wall', 'Mural Comments'],
    );
    expect(
      container
          .read(filteredARWallsProvider(ARWallFilter.trending))
          .map((wall) => wall.title),
      ['Mural Comments'],
    );
    expect(
      container
          .read(filteredARWallsProvider(ARWallFilter.public))
          .map((wall) => wall.title),
      ['Mural Comments', 'Weekend Market'],
    );
    expect(
      container
          .read(filteredARWallsProvider(ARWallFilter.group))
          .map((wall) => wall.title),
      ['Class Reunion Wall'],
    );
  });

  test('wall search narrows the selected filter', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container
          .read(
            visibleARWallsProvider(
              (filter: ARWallFilter.public, query: 'market'),
            ),
          )
          .map((wall) => wall.title),
      ['Weekend Market'],
    );
    expect(
      container
          .read(
            visibleARWallsProvider(
              (filter: ARWallFilter.nearby, query: 'market'),
            ),
          )
          .map((wall) => wall.title),
      isEmpty,
    );
    expect(
      container
          .read(
            visibleARWallsProvider(
              (filter: ARWallFilter.nearby, query: 'mural'),
            ),
          )
          .map((wall) => wall.title),
      ['Mural Comments'],
    );
    expect(
      container
          .read(
            visibleARWallsProvider(
              (filter: ARWallFilter.nearby, query: 'courtyard'),
            ),
          )
          .map((wall) => wall.title),
      ['Class Reunion Wall'],
    );
    expect(
      container
          .read(
            visibleARWallsProvider(
              (filter: ARWallFilter.public, query: 'rooftop'),
            ),
          )
          .map((wall) => wall.title),
      ['Weekend Market'],
    );
  });

  test('creating a wall prepends an active nearby wall', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(arWallsProvider.notifier);

    controller.createWall(
      title: '  Study Wall  ',
      description: '  Notes for the library corner.  ',
      isPublic: false,
    );

    final createdWall = container.read(arWallsProvider).first;

    expect(createdWall.title, 'Study Wall');
    expect(createdWall.description, 'Notes for the library corner.');
    expect(createdWall.distanceLabel, '0 m');
    expect(createdWall.memberCount, 1);
    expect(createdWall.itemCount, 0);
    expect(createdWall.isPublic, isFalse);
    expect(createdWall.isActive, isTrue);
    expect(createdWall.items, isEmpty);
    expect(createdWall.linkedMemoryIds, isEmpty);
    expect(
      container.read(filteredARWallsProvider(ARWallFilter.nearby)).first.title,
      'Study Wall',
    );

    controller.createWall(
      title: '   ',
      description: 'Ignored',
      isPublic: true,
    );

    expect(container.read(arWallsProvider).first.title, 'Study Wall');
  });

  test('creating a wall stores selected linked memories once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(arWallsProvider.notifier).createWall(
      title: 'Trail Wall',
      description: 'Anchors for the walking route.',
      isPublic: true,
      linkedMemoryIds: const [
        'anchor_courtyard',
        ' anchor_private ',
        'anchor_courtyard',
        '   ',
      ],
    );

    final createdWall = container.read(arWallsProvider).first;

    expect(createdWall.title, 'Trail Wall');
    expect(
      createdWall.linkedMemoryIds,
      ['anchor_courtyard', 'anchor_private'],
    );
    expect(createdWall.linkedMemoryCountLabel, '2 linked memories');
  });

  test('linked wall memories resolve in configured wall order', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final linkedMemories =
        container.read(wallLinkedMemoriesProvider('wall_reunion'));

    expect(
      linkedMemories.map((memory) => memory.id),
      ['anchor_courtyard', 'anchor_private'],
    );
    expect(linkedMemories.first.title, 'Courtyard sketch');
    expect(
      container.read(wallLinkedMemoriesProvider('missing_wall')),
      isEmpty,
    );
  });

  test('wall trail previews summarize ordered linked memories', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final linkedMemories =
        container.read(wallLinkedMemoriesProvider('wall_reunion'));
    final preview = wallTrailPreviewFor(linkedMemories)!;

    expect(preview.stopCount, 2);
    expect(
      preview.orderedMemoryIds,
      ['anchor_courtyard', 'anchor_private'],
    );
    expect(preview.routeDistanceMeters, greaterThan(0));
    expect(preview.firstStopTitle, 'Courtyard sketch');
    expect(preview.lastStopTitle, 'Family checkpoint');
    expect(preview.routeSummaryLabel, contains('2 stops - '));
    expect(preview.routeSummaryLabel, contains(' route'));
    expect(preview.compactRouteLabel, contains('min walk'));
    expect(preview.privateStopCount, 1);
    expect(preview.calibrationReviewCount, 0);
    expect(preview.privacyLabel, '1 private stop');
    expect(preview.anchorHealthLabel, 'Anchors ready');
    expect(
      preview.startEndLabel,
      'Courtyard sketch to Family checkpoint',
    );
    expect(wallTrailPreviewFor(const []), isNull);
  });

  test('wall trail previews can start from the nearest viewer anchor', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final reversedMemories =
        container.read(wallLinkedMemoriesProvider('wall_reunion')).reversed;
    final preview = wallTrailPreviewFor(
      reversedMemories.toList(),
      originLatitude: viewerLatitude,
      originLongitude: viewerLongitude,
      optimizeFromOrigin: true,
    )!;

    expect(
      preview.orderedMemoryIds,
      ['anchor_courtyard', 'anchor_private'],
    );
    expect(preview.firstStopTitle, 'Courtyard sketch');
    expect(preview.startDistanceLabel, 'Starts at your position');
    expect(preview.walkTimeLabel, endsWith('min walk'));
  });

  test('wall trail previews surface route privacy and calibration advisories',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final linkedMemories = container
        .read(wallLinkedMemoriesProvider('wall_reunion'))
        .map(
          (memory) => memory.id == 'anchor_courtyard'
              ? memory.copyWith(
                  captureMetadata: memory.captureMetadata.copyWith(
                    gpsAccuracyMeters: 14,
                  ),
                )
              : memory,
        )
        .toList();
    final preview = wallTrailPreviewFor(linkedMemories)!;

    expect(preview.hasRouteAdvisories, isTrue);
    expect(preview.hasPrivateStops, isTrue);
    expect(preview.hasCalibrationReviews, isTrue);
    expect(preview.privacyLabel, '1 private stop');
    expect(preview.anchorHealthLabel, '1 stop needs calibration');
  });

  test('updating wall links replaces linked memories', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(arWallsProvider.notifier).updateLinkedMemoryIds(
      wallId: 'wall_reunion',
      linkedMemoryIds: const [
        'anchor_mural',
        ' anchor_mural ',
        'anchor_rooftop',
        '   ',
      ],
    );

    final updatedWall = container
        .read(arWallsProvider)
        .singleWhere((wall) => wall.id == 'wall_reunion');

    expect(
      updatedWall.linkedMemoryIds,
      ['anchor_mural', 'anchor_rooftop'],
    );
    expect(
      container
          .read(wallLinkedMemoriesProvider('wall_reunion'))
          .map((memory) => memory.title),
      ['Hidden mural frame', 'Rooftop sunset'],
    );

    container.read(arWallsProvider.notifier).updateLinkedMemoryIds(
      wallId: 'missing_wall',
      linkedMemoryIds: const ['anchor_private'],
    );

    expect(container.read(arWallsProvider).length, 3);
  });

  test('linking a memory to walls appends the memory once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(arWallsProvider.notifier).linkMemoryToWalls(
      memoryId: 'captured_memory',
      wallIds: const ['wall_reunion', ' wall_market ', 'wall_reunion'],
    );
    container.read(arWallsProvider.notifier).linkMemoryToWalls(
      memoryId: 'captured_memory',
      wallIds: const ['wall_reunion'],
    );

    final reunionWall = container
        .read(arWallsProvider)
        .singleWhere((wall) => wall.id == 'wall_reunion');
    final marketWall = container
        .read(arWallsProvider)
        .singleWhere((wall) => wall.id == 'wall_market');

    expect(
      reunionWall.linkedMemoryIds.where((id) => id == 'captured_memory'),
      ['captured_memory'],
    );
    expect(marketWall.linkedMemoryIds.last, 'captured_memory');
  });

  test('memory linked walls resolve every wall using an anchor', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final linkedWalls =
        container.read(memoryLinkedWallsProvider('anchor_courtyard'));

    expect(linkedWalls.map((wall) => wall.id), ['wall_reunion']);
    expect(linkedWalls.first.title, 'Class Reunion Wall');
    expect(
      container.read(memoryLinkedWallsProvider('missing_anchor')),
      isEmpty,
    );
    expect(
      container.read(memoryLinkedWallsProvider('   ')),
      isEmpty,
    );
  });

  test('adding a wall item prepends content and increments count', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(arWallsProvider.notifier);
    final initialWall = container
        .read(arWallsProvider)
        .singleWhere((wall) => wall.id == 'wall_reunion');

    controller.addWallItem(
      wallId: 'wall_reunion',
      type: WallItemType.note,
      content: '  Bring snacks  ',
    );

    final updatedWall = container
        .read(arWallsProvider)
        .singleWhere((wall) => wall.id == 'wall_reunion');

    expect(updatedWall.itemCount, initialWall.itemCount + 1);
    expect(updatedWall.items, hasLength(initialWall.items.length + 1));
    expect(updatedWall.items.first.content, 'Bring snacks');
    expect(updatedWall.items.first.type, WallItemType.note);
    expect(updatedWall.items.first.author, 'You');

    controller.addWallItem(
      wallId: 'wall_reunion',
      type: WallItemType.note,
      content: '   ',
    );

    expect(
      container
          .read(arWallsProvider)
          .singleWhere((wall) => wall.id == 'wall_reunion')
          .items,
      hasLength(updatedWall.items.length),
    );
  });

  test('inviting a member increments wall membership', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(arWallsProvider.notifier);
    final initialWall = container
        .read(arWallsProvider)
        .singleWhere((wall) => wall.id == 'wall_reunion');

    controller.inviteMember(
      wallId: 'wall_reunion',
      invitee: '  Maya  ',
    );

    final updatedWall = container
        .read(arWallsProvider)
        .singleWhere((wall) => wall.id == 'wall_reunion');

    expect(updatedWall.memberCount, initialWall.memberCount + 1);
    expect(updatedWall.memberCountLabel, '25 members');

    controller.inviteMember(
      wallId: 'wall_reunion',
      invitee: '   ',
    );

    expect(
      container
          .read(arWallsProvider)
          .singleWhere((wall) => wall.id == 'wall_reunion')
          .memberCount,
      updatedWall.memberCount,
    );
  });
}
