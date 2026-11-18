import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_overlay_anchor_selector.dart';

class _Item {
  const _Item(this.id, this.distance, {this.visible = true});

  final String id;
  final double distance;
  final bool visible;
}

List<String> _select(
  List<_Item> items, {
  String? focused,
  Set<String> placed = const {},
  int maxCards = AROverlayAnchorSelector.defaultMaxCards,
}) {
  return AROverlayAnchorSelector.select<_Item>(
    items,
    idOf: (item) => item.id,
    distanceMetersOf: (item) => item.distance,
    isVisibleOf: (item) => item.visible,
    focusedId: focused,
    nativelyPlacedIds: placed,
    maxCards: maxCards,
  ).map((item) => item.id).toList();
}

void main() {
  test('excludes memories already placed in the native scene', () {
    final ids = _select(
      const [_Item('a', 2), _Item('b', 3), _Item('c', 4)],
      placed: {'a', 'c'},
    );

    expect(ids, ['b']);
  });

  test('draws nothing when every memory is placed natively', () {
    expect(
      _select(const [_Item('a', 2), _Item('b', 3)], placed: {'a', 'b'}),
      isEmpty,
    );
  });

  test('puts the focused memory first, then nearest on-screen memories', () {
    final ids = _select(
      const [_Item('far', 9), _Item('near', 1), _Item('focus', 5)],
      focused: 'focus',
    );

    expect(ids, ['focus', 'near', 'far']);
  });

  test('caps the number of fallback cards at three by default', () {
    final ids = _select(
      [for (var i = 0; i < 8; i++) _Item('m$i', i.toDouble())],
    );

    expect(ids, ['m0', 'm1', 'm2']);
  });

  test('drops off-screen memories but keeps an off-screen focused one', () {
    final ids = _select(
      const [
        _Item('off', 1, visible: false),
        _Item('focus', 8, visible: false),
        _Item('on', 4),
      ],
      focused: 'focus',
    );

    expect(ids, ['focus', 'on']);
  });

  test('does not show a focused memory that is placed natively', () {
    final ids = _select(
      const [_Item('focus', 1), _Item('on', 2)],
      focused: 'focus',
      placed: {'focus'},
    );

    expect(ids, ['on']);
  });

  test('orders ties by id so the result is stable', () {
    final ids = _select(const [_Item('b', 2), _Item('a', 2)]);

    expect(ids, ['a', 'b']);
  });

  test('a non-positive cap returns nothing', () {
    expect(_select(const [_Item('a', 1)], maxCards: 0), isEmpty);
  });
}
