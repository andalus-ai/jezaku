import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/profile/states/profile_providers.dart';

void main() {
  test('profile controller trims names and normalizes handles', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(userProfileProvider.notifier).updateProfile(
          displayName: '  Alya Trail  ',
          handle: 'Trail Maker!',
        );

    final profile = container.read(userProfileProvider);

    expect(profile.displayName, 'Alya Trail');
    expect(profile.handle, '@trail.maker');
    expect(profile.initial, 'A');
  });

  test('profile controller keeps existing values for blank edits', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(userProfileProvider.notifier).updateProfile(
          displayName: '   ',
          handle: '   ',
        );

    final profile = container.read(userProfileProvider);

    expect(profile.displayName, 'Jejaku Explorer');
    expect(profile.handle, '@jejaku.explorer');
  });
}
