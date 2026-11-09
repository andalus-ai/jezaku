import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/parent/models/child_account.dart';
import 'package:jejaku/features/parent/states/parent_providers.dart';

void main() {
  test('adding a child creates a default safety profile', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(childAccountsProvider.notifier);
    final initialChildren = container.read(childAccountsProvider);

    controller.addChild(name: '  Zia  ', age: 9);

    final children = container.read(childAccountsProvider);
    final zia = children.first;

    expect(children, hasLength(initialChildren.length + 1));
    expect(zia.name, 'Zia');
    expect(zia.age, 9);
    expect(zia.isOnline, isFalse);
    expect(zia.todayScreenTime, Duration.zero);
    expect(zia.hasPendingExtension, isFalse);
    expect(zia.safeZones, isEmpty);
    expect(zia.restrictions.dailyLimit, const Duration(minutes: 45));
    expect(zia.restrictions.hidePreciseLocation, isTrue);

    controller.addChild(name: '   ', age: 11);

    expect(container.read(childAccountsProvider), hasLength(children.length));
  });

  test('approving a screen time extension clears request and raises limit', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(childAccountsProvider.notifier);
    final anna = container
        .read(childAccountsProvider)
        .singleWhere((child) => child.id == 'anna');

    expect(anna.hasPendingExtension, isTrue);
    expect(anna.restrictions.dailyLimit, const Duration(minutes: 45));

    controller.approveExtensionRequest('anna');

    final updatedAnna = container
        .read(childAccountsProvider)
        .singleWhere((child) => child.id == 'anna');

    expect(updatedAnna.hasPendingExtension, isFalse);
    expect(updatedAnna.restrictions.dailyLimit, const Duration(minutes: 60));
  });

  test('denying a screen time extension clears request without changing limit',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(childAccountsProvider.notifier);

    controller.denyExtensionRequest('anna');

    final anna = container
        .read(childAccountsProvider)
        .singleWhere((child) => child.id == 'anna');

    expect(anna.hasPendingExtension, isFalse);
    expect(anna.restrictions.dailyLimit, const Duration(minutes: 45));
  });

  test('adding a geofence appends a sanitized child zone', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(childAccountsProvider.notifier);
    final initialAnna = container
        .read(childAccountsProvider)
        .singleWhere((child) => child.id == 'anna');

    controller.addGeofence(
      childId: 'anna',
      name: '  Library  ',
      radiusMeters: 20,
      type: GeoFenceType.alert,
    );

    final updatedAnna = container
        .read(childAccountsProvider)
        .singleWhere((child) => child.id == 'anna');
    final addedZone = updatedAnna.safeZones.last;

    expect(updatedAnna.safeZones, hasLength(initialAnna.safeZones.length + 1));
    expect(addedZone.name, 'Library');
    expect(addedZone.radiusMeters, 50);
    expect(addedZone.type, GeoFenceType.alert);

    controller.addGeofence(
      childId: 'anna',
      name: '   ',
      radiusMeters: 150,
      type: GeoFenceType.safe,
    );

    expect(
      container
          .read(childAccountsProvider)
          .singleWhere((child) => child.id == 'anna')
          .safeZones,
      hasLength(updatedAnna.safeZones.length),
    );
  });
}
