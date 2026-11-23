import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/frame_styles/models/frame_look.dart';
import 'package:jejaku/features/frame_styles/services/frame_style_resolver.dart';

void main() {
  group('frame look catalog', () {
    test('has several looks with unique ids, classic first', () {
      final ids = builtInFrameLooks.map((look) => look.id).toList();
      expect(ids.length, greaterThanOrEqualTo(4));
      expect(ids.toSet().length, ids.length);
      expect(ids.first, defaultFrameLookId);
    });

    test('an unknown or missing id falls back to classic', () {
      expect(frameLookById(null).id, defaultFrameLookId);
      expect(frameLookById('from-a-future-marketplace').id, defaultFrameLookId);
      expect(frameLookById('gold').label, 'Gold');
    });
  });

  group('FrameStyleResolver', () {
    test('untouched classic emits no metadata (existing frames unchanged)', () {
      expect(
        FrameStyleResolver.sceneMetadata(lookId: 'classic'),
        isEmpty,
      );
      expect(FrameStyleResolver.sceneMetadata(lookId: null), isEmpty);
    });

    test('a preset look names its preset without a custom style', () {
      final metadata = FrameStyleResolver.sceneMetadata(lookId: 'dark_gallery');
      expect(metadata['photoFramePreset'], 'darkGallery');
      expect(metadata.containsKey('photoFrameStyle'), isFalse);
    });

    test('a colour adds a style with recoloured materials', () {
      final metadata = FrameStyleResolver.sceneMetadata(
        lookId: 'classic',
        colorValue: 0xFFC0392B,
      );
      expect(metadata['photoFramePreset'], 'classic');
      final style = metadata['photoFrameStyle']! as Map<String, Object?>;
      expect(style['preset'], 'classic');
      expect(style['frameMaterial'], isA<Map<Object?, Object?>>());
      expect(style['backingMaterial'], isA<Map<Object?, Object?>>());
      expect(style['highlightMaterial'], isA<Map<Object?, Object?>>());
    });

    test('a look that carries its own colour is styled, an override wins', () {
      expect(
        FrameStyleResolver.effectiveColorValue('gold', null),
        0xFFD4AF37,
      );
      expect(
        FrameStyleResolver.effectiveColorValue('gold', 0xFF2E6FD8),
        0xFF2E6FD8,
      );
      expect(
        FrameStyleResolver.sceneMetadata(lookId: 'gold')
            .containsKey('photoFrameStyle'),
        isTrue,
      );
    });

    test('preview colour is opaque for solid looks', () {
      final argb = FrameStyleResolver.previewColorValue('oak', null);
      expect(argb, 0xFFB5865A);
    });

    test('preview border fraction stays within bounds', () {
      for (final look in builtInFrameLooks) {
        final fraction = FrameStyleResolver.previewBorderFraction(look.id);
        expect(fraction, inInclusiveRange(0.03, 0.12));
      }
    });
  });
}
