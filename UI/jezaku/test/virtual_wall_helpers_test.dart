import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/widgets/add_wall_item_dialog.dart';
import 'package:jejaku/features/virtual_wall/widgets/wall_route_authoring_widgets.dart';

void main() {
  group('moveWallMemoryId', () {
    test('moves an id down and up by the delta', () {
      final ids = ['a', 'b', 'c'];

      moveWallMemoryId(ids, 'a', 1);
      expect(ids, ['b', 'a', 'c']);

      moveWallMemoryId(ids, 'c', -2);
      expect(ids, ['c', 'b', 'a']);
    });

    test('clamps at both ends instead of wrapping', () {
      final ids = ['a', 'b', 'c'];

      moveWallMemoryId(ids, 'a', -1);
      moveWallMemoryId(ids, 'c', 5);

      expect(ids, ['a', 'b', 'c']);
    });

    test('ignores an id that is not in the list', () {
      final ids = ['a', 'b'];

      moveWallMemoryId(ids, 'z', 1);

      expect(ids, ['a', 'b']);
    });
  });

  test('wallItemTypeLabel names every item type', () {
    expect(<String>[
      for (final type in WallItemType.values) wallItemTypeLabel(type),
    ], ['Photo', 'Note', 'Drawing', 'Audio', '3D item']);
  });
}
