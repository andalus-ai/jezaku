import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/profile/models/profile_rules.dart';

void main() {
  group('normalizeHandle', () {
    test('lowercases, dots spaces and strips symbols', () {
      expect(ProfileRules.normalizeHandle('Trail Maker!'), '@trail.maker');
      expect(ProfileRules.normalizeHandle('@Alya_99'), '@alya_99');
    });

    test('collapses repeated dots and trims edge punctuation', () {
      expect(ProfileRules.normalizeHandle('..a   b..c..'), '@a.b.c');
    });

    test('returns empty when nothing usable remains', () {
      expect(ProfileRules.normalizeHandle('  !!! '), '');
      expect(ProfileRules.normalizeHandle(''), '');
    });
  });

  group('displayNameError', () {
    test('requires a name', () {
      expect(ProfileRules.displayNameError('   '), 'Name required');
    });

    test('limits the length by characters, not bytes', () {
      expect(ProfileRules.displayNameError('a' * 40), isNull);
      expect(ProfileRules.displayNameError('a' * 41), isNotNull);
      expect(ProfileRules.displayNameError('😀' * 40), isNull);
    });

    test('truncates on whole characters', () {
      expect(ProfileRules.truncateDisplayName('😀' * 50).runes.length, 40);
      expect(ProfileRules.truncateDisplayName('  Alya  '), 'Alya');
    });
  });

  group('handleError', () {
    test('a blank handle means unchanged and is allowed', () {
      expect(ProfileRules.handleError('   '), isNull);
    });

    test('enforces the length bounds', () {
      expect(ProfileRules.handleError('ab'), isNotNull);
      expect(ProfileRules.handleError('abc'), isNull);
      expect(ProfileRules.handleError('a' * 24), isNull);
      expect(ProfileRules.handleError('a' * 25), isNotNull);
    });

    test('rejects input that normalizes to nothing', () {
      expect(ProfileRules.handleError('!!!'), isNotNull);
    });

    test('reserves official-sounding handles', () {
      expect(ProfileRules.handleError('@Admin'), 'That handle is reserved');
      expect(ProfileRules.handleError('Support'), 'That handle is reserved');
      expect(ProfileRules.handleError('support.team'), isNull);
    });
  });
}
