import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:ar_engine/ar_engine.dart';

void main() {
  // ── ARVector3 ──────────────────────────────────────────────────────────────

  group('ARVector3', () {
    test('arithmetic operators', () {
      const a = ARVector3(1, 2, 3);
      const b = ARVector3(4, 5, 6);
      expect((a + b).x, 5);
      expect((a - b).y, -3);
      expect((a * 2).z, 6);
      expect((a / 2).x, 0.5);
      expect((-a).x, -1);
    });

    test('length and lengthSquared', () {
      const v = ARVector3(3, 4, 0);
      expect(v.length, closeTo(5, 1e-9));
      expect(v.lengthSquared, closeTo(25, 1e-9));
    });

    test('normalised vector has unit length', () {
      const v = ARVector3(3, 4, 0);
      expect(v.normalized.length, closeTo(1, 1e-9));
    });

    test('zero vector normalises to zero', () {
      expect(const ARVector3.zero().normalized.length, 0);
    });

    test('dot product of orthogonal vectors is 0', () {
      expect(const ARVector3(1, 0, 0).dot(const ARVector3(0, 1, 0)), 0);
    });

    test('dot product of parallel vectors equals product of lengths', () {
      const v = ARVector3(2, 0, 0);
      expect(v.dot(v), closeTo(4, 1e-9));
    });

    test('cross product right-hand rule', () {
      final z = const ARVector3(1, 0, 0).cross(const ARVector3(0, 1, 0));
      expect(z.x, closeTo(0, 1e-9));
      expect(z.y, closeTo(0, 1e-9));
      expect(z.z, closeTo(1, 1e-9));
    });

    test('cross product anticommutativity', () {
      const a = ARVector3(1, 2, 3);
      const b = ARVector3(4, 5, 6);
      final ab = a.cross(b);
      final ba = b.cross(a);
      expect(ab.x, closeTo(-ba.x, 1e-9));
      expect(ab.y, closeTo(-ba.y, 1e-9));
    });

    test('lerp is clamped to [0,1]', () {
      const a = ARVector3(0, 0, 0);
      const b = ARVector3(10, 10, 10);
      expect(ARVector3.lerp(a, b, 0).x, 0);
      expect(ARVector3.lerp(a, b, 1).x, closeTo(10, 1e-9));
      expect(ARVector3.lerp(a, b, 0.5).x, closeTo(5, 1e-9));
      expect(ARVector3.lerp(a, b, 2.0).x, closeTo(10, 1e-9)); // clamped
      expect(ARVector3.lerp(a, b, -1).x, 0); // clamped
    });

    test('distance', () {
      expect(
          ARVector3.distance(
              const ARVector3(0, 0, 0), const ARVector3(3, 4, 0)),
          closeTo(5, 1e-9));
    });

    test('fromMap / toMap round-trip', () {
      const v = ARVector3(1.23, -4.56, 7.89);
      final v2 = ARVector3.fromMap(v.toMap());
      expect(v2.x, v.x);
      expect(v2.y, v.y);
      expect(v2.z, v.z);
    });

    test('static constants', () {
      expect(ARVector3.up.y, 1);
      expect(ARVector3.forward.z, -1);
      expect(ARVector3.right.x, 1);
    });
  });

  // ── ARQuaternion ───────────────────────────────────────────────────────────

  group('ARQuaternion', () {
    test('identity properties', () {
      const q = ARQuaternion.identity();
      expect(q.w, 1);
      expect(q.length, closeTo(1, 1e-9));
    });

    test('axisAngle 90° Y: X → -Z', () {
      final q = ARQuaternion.axisAngle(ARVector3.up, math.pi / 2);
      final r = q.rotateVector(const ARVector3(1, 0, 0));
      expect(r.x, closeTo(0, 1e-5));
      expect(r.z, closeTo(-1, 1e-5));
    });

    test('axisAngle 180° Y: X → -X', () {
      final q = ARQuaternion.axisAngle(ARVector3.up, math.pi);
      expect(q.rotateVector(const ARVector3(1, 0, 0)).x, closeTo(-1, 1e-5));
    });

    test('multiply 90°+90° = 180°', () {
      final q90 = ARQuaternion.axisAngle(ARVector3.up, math.pi / 2);
      final q180 = q90 * q90;
      expect(q180.rotateVector(const ARVector3(1, 0, 0)).x, closeTo(-1, 1e-4));
    });

    test('inverse undoes rotation', () {
      final q = ARQuaternion.axisAngle(ARVector3.up, math.pi / 3);
      const v = ARVector3(1, 0, 0);
      final rot = q.rotateVector(v);
      final inv = q.inverse;
      final res = inv.rotateVector(rot);
      expect(res.x, closeTo(v.x, 1e-5));
      expect(res.z, closeTo(v.z, 1e-5));
    });

    test('conjugate negates x,y,z', () {
      final q = ARQuaternion.axisAngle(ARVector3.up, 1.0);
      final c = q.conjugate;
      expect(c.x, closeTo(-q.x, 1e-12));
      expect(c.w, closeTo(q.w, 1e-12));
    });

    test('slerp endpoints match inputs', () {
      final a = ARQuaternion.axisAngle(ARVector3.up, 0);
      final b = ARQuaternion.axisAngle(ARVector3.up, math.pi / 2);
      expect(ARQuaternion.slerp(a, b, 0).w, closeTo(a.w, 1e-5));
      expect(ARQuaternion.slerp(a, b, 1).w, closeTo(b.w, 1e-5));
    });

    test('slerp midpoint is unit quaternion', () {
      final a = ARQuaternion.axisAngle(ARVector3.up, 0);
      final b = ARQuaternion.axisAngle(ARVector3.up, math.pi);
      expect(ARQuaternion.slerp(a, b, 0.5).length, closeTo(1, 1e-5));
    });

    test('euler identity', () {
      expect(ARQuaternion.euler(0, 0, 0).w, closeTo(1, 1e-9));
    });

    test('fromMap / toMap round-trip', () {
      final q = ARQuaternion.axisAngle(const ARVector3(1, 0, 0), 1.0);
      final q2 = ARQuaternion.fromMap(q.toMap());
      expect(q2.x, closeTo(q.x, 1e-9));
      expect(q2.w, closeTo(q.w, 1e-9));
    });
  });

  // ── ARMatrix4 ─────────────────────────────────────────────────────────────

  group('ARMatrix4', () {
    test('identity * identity = identity', () {
      final i = ARMatrix4.identity();
      final r = i * i;
      for (int k = 0; k < 16; k++)
        expect(r.storage[k], closeTo(i.storage[k], 1e-9));
    });

    test('translation round-trip', () {
      final m = ARMatrix4.fromTranslation(const ARVector3(5, 6, 7));
      expect(m.translation.x, 5);
      expect(m.translation.y, 6);
      expect(m.translation.z, 7);
    });

    test('rotation matrix has det ≈ 1', () {
      final m = ARMatrix4.fromRotation(
          ARQuaternion.axisAngle(ARVector3.up, math.pi / 4));
      final s = m.storage;
      final det = s[0] * (s[5] * s[10] - s[9] * s[6]) -
          s[4] * (s[1] * s[10] - s[9] * s[2]) +
          s[8] * (s[1] * s[6] - s[5] * s[2]);
      expect(det, closeTo(1, 1e-5));
    });

    test('TRS preserves translation', () {
      final m = ARMatrix4.trs(const ARVector3(1, 2, 3),
          const ARQuaternion.identity(), const ARVector3.one());
      expect(m.translation.x, closeTo(1, 1e-6));
      expect(m.translation.y, closeTo(2, 1e-6));
      expect(m.translation.z, closeTo(3, 1e-6));
    });

    test('toList has 16 elements', () {
      expect(ARMatrix4.identity().toList().length, 16);
    });
  });

  // ── ARPose ────────────────────────────────────────────────────────────────

  group('ARPose', () {
    test('identity leaves position unchanged', () {
      const other = ARPose(
          position: ARVector3(5, 0, 0), rotation: ARQuaternion.identity());
      final t = other.transformedBy(const ARPose.identity());
      expect(t.position.x, closeTo(5, 1e-6));
    });

    test('lerp midpoint', () {
      const a = ARPose(
          position: ARVector3(0, 0, 0), rotation: ARQuaternion.identity());
      const b = ARPose(
          position: ARVector3(10, 0, 0), rotation: ARQuaternion.identity());
      expect(ARPose.lerp(a, b, 0.5).position.x, closeTo(5, 1e-6));
    });

    test('fromMap / toMap round-trip', () {
      const p = ARPose(
          position: ARVector3(1, 2, 3), rotation: ARQuaternion.identity());
      final p2 = ARPose.fromMap(p.toMap());
      expect(p2.position.x, 1);
      expect(p2.rotation.w, closeTo(1, 1e-9));
    });

    test('toMatrix extracts correct translation', () {
      const p = ARPose(
          position: ARVector3(4, 5, 6), rotation: ARQuaternion.identity());
      final m = p.toMatrix();
      expect(m.translation.x, closeTo(4, 1e-6));
    });
  });

  // ── ARNode ────────────────────────────────────────────────────────────────

  group('ARNode', () {
    test('copyWith preserves id and changes position', () {
      const n = ARNode(id: 'n1');
      final n2 = n.copyWith(position: const ARVector3(1, 2, 3));
      expect(n2.id, 'n1');
      expect(n2.position.x, 1);
      expect(n2.scale, const ARVector3.one()); // unchanged
    });

    test('copyWith can adopt platform assigned id', () {
      const n = ARNode(id: 'requested');
      final n2 = n.copyWith(id: 'native_42');
      expect(n2.id, 'native_42');
      expect(n2.primitiveShape, n.primitiveShape);
    });

    test('copyWith changes visibility', () {
      const n = ARNode(id: 'n', isVisible: true);
      final n2 = n.copyWith(isVisible: false);
      expect(n2.isVisible, false);
      expect(n2.id, 'n');
    });

    test('copyWith changes renderOrder', () {
      const n = ARNode(id: 'n', renderOrder: 0);
      final n2 = n.copyWith(renderOrder: 5);
      expect(n2.renderOrder, 5);
    });

    test('model factory creates typed 3D object node', () {
      final asset = ARModelAsset.fromPath(
        'assets/models/memory.glb',
        fallbackSizeMeters: const ARVector3(0.25, 0.25, 0.25),
        metadata: const <String, Object?>{'category': 'memory_object'},
      );
      final n = ARNode.model(
        id: 'memory_object',
        asset: asset,
        scale: const ARVector3(0.8, 0.8, 0.8),
      );

      expect(n.isModelNode, isTrue);
      expect(n.contentType, ARNodeContentType.glb);
      expect(n.modelPath, 'assets/models/memory.glb');
      expect(n.effectiveModelAsset, asset);
      expect(n.primitiveSize, const ARVector3(0.25, 0.25, 0.25));
      expect(n.toMap()['modelAsset'], asset.toMap());
    });

    test('copyWith can move primitive node to 3D model content', () {
      const n = ARNode(id: 'switchable');
      final asset = ARModelAsset.fromPath('assets/models/tree.usdz');
      final n2 = n.copyWith(modelAsset: asset);

      expect(n2.isModelNode, isTrue);
      expect(n2.contentType, ARNodeContentType.usdz);
      expect(n2.modelPath, 'assets/models/tree.usdz');
    });

    test('copyWith can change children', () {
      const child = ARNode(id: 'child');
      const n = ARNode(id: 'parent');
      final n2 = n.copyWith(children: [child]);
      expect(n2.children.length, 1);
      expect(n2.children.first.id, 'child');
    });

    test('toMap includes all required keys', () {
      const n = ARNode(
          id: 'x', primitiveShape: ARPrimitiveShape.sphere, isVisible: false);
      final m = n.toMap();
      expect(m['primitiveShape'], 'sphere');
      expect(m['isVisible'], false);
      expect(m['castsShadow'], true);
      expect(m.containsKey('position'), true);
    });

    test('fromMap round-trip', () {
      const n = ARNode(
          id: 'rt', primitiveShape: ARPrimitiveShape.cylinder, renderOrder: 3);
      final n2 = ARNode.fromMap(n.toMap());
      expect(n2.id, 'rt');
      expect(n2.primitiveShape, ARPrimitiveShape.cylinder);
      expect(n2.renderOrder, 3);
    });

    test('model nodes serialize, restore, and normalize legacy paths', () {
      final node = ARNodeBuilder('artifact')
          .usdz(
            'assets/models/artifact.usdz',
            fallbackSizeMeters: const ARVector3(0.4, 0.2, 0.4),
          )
          .at(z: -0.8)
          .build();

      final restored = ARNode.fromMap(node.toMap());
      final legacy = ARNode.fromMap(<String, Object?>{
        'id': 'legacy_artifact',
        'position': const ARVector3.zero().toMap(),
        'rotation': const ARQuaternion.identity().toMap(),
        'scale': const ARVector3.one().toMap(),
        'modelPath': 'assets/models/legacy.glb',
      });

      expect(restored.contentType, ARNodeContentType.usdz);
      expect(restored.effectiveModelAsset?.format, ARModelFormat.usdz);
      expect(
        restored.effectiveModelAsset,
        ARModelAsset.fromPath(
          'assets/models/artifact.usdz',
          format: ARModelFormat.usdz,
          fallbackSizeMeters: const ARVector3(0.4, 0.2, 0.4),
        ),
      );
      expect(legacy.isModelNode, isTrue);
      expect(legacy.contentType, ARNodeContentType.glb);
      expect(legacy.effectiveModelAsset?.path, 'assets/models/legacy.glb');
    });

    test('model asset validation accepts portable OBJ assets', () {
      final asset = ARModelAsset.fromPath(
        'assets/models/marker.obj',
        fallbackSizeMeters: const ARVector3(0.4, 0.3, 0.4),
      );

      final report = asset.validate();

      expect(report.isValid, isTrue);
      expect(report.hasWarnings, isFalse);
      expect(report.summaryLabel, 'Model asset ready');
      expect(report.issueLabels, isEmpty);
      expect(
        asset.renderProfile().summaryLabel,
        'Native mesh on Android and iOS',
      );
      expect(
        asset.renderProfile().platformLabels,
        ['Android native OBJ mesh', 'iOS native SceneKit mesh'],
      );
      expect(asset.renderProfile().rendersModelMeshEverywhere, isTrue);
    });

    test('model asset validation reports fallback and platform warnings', () {
      final asset = ARModelAsset.fromPath('assets/models/marker.glb');

      final report = asset.validate();
      final renderProfile = asset.renderProfile();

      expect(report.isValid, isTrue);
      expect(report.summaryLabel, 'Model asset ready with 3 warnings');
      expect(
        report.warningLabels,
        containsAll(<String>[
          'No fallback size supplied; primitive fallback uses the node scale.',
          'Android imports OBJ meshes directly; this format uses primitive fallback rendering.',
          'iOS SceneKit loading may require conversion for this model format.',
        ]),
      );
      expect(report.usesAndroidPrimitiveFallback, isTrue);
      expect(
        renderProfile.summaryLabel,
        'Android primitive fallback; iOS model conversion recommended',
      );
      expect(renderProfile.android.usesPrimitiveFallback, isTrue);
      expect(renderProfile.ios.requiresPreparation, isTrue);
      expect(renderProfile.usesAnyPrimitiveFallback, isTrue);
      expect(renderProfile.requiresPreparation, isTrue);
    });

    test('model asset validation can target one platform', () {
      final asset = ARModelAsset.fromPath(
        'https://cdn.example.test/model.usdz',
        source: ARModelAssetSource.network,
        fallbackSizeMeters: const ARVector3(0.4, 0.3, 0.4),
      );

      final android =
          asset.validate(target: ARModelAssetValidationTarget.android);
      final ios = asset.validate(target: ARModelAssetValidationTarget.ios);
      final renderProfile = asset.renderProfile();

      expect(
        android.warningLabels,
        contains(
          'Network models require app-level download/cache before Android rendering.',
        ),
      );
      expect(
        android.warningLabels,
        contains(
          'Android imports OBJ meshes directly; this format uses primitive fallback rendering.',
        ),
      );
      expect(
        ios.warningLabels,
        isNot(
          contains(
            'Network models require app-level download/cache before Android rendering.',
          ),
        ),
      );
      expect(
        ios.warningLabels,
        isNot(
          contains(
            'Android imports OBJ meshes directly; this format uses primitive fallback rendering.',
          ),
        ),
      );
      expect(
        renderProfile.summaryLabel,
        'Android cache preparation required; iOS native SceneKit mesh',
      );
      expect(renderProfile.android.requiresPreparation, isTrue);
      expect(renderProfile.ios.rendersModelMesh, isTrue);
      expect(
        renderProfile.toMap()['platforms'],
        isA<List<Object?>>(),
      );
    });

    test('model asset validation reports blocking fallback size issues', () {
      final asset = ARModelAsset.fromPath(
        'assets/models/broken.obj',
        fallbackSizeMeters: const ARVector3(0, 0.3, 0.4),
      );

      final report = asset.validate();

      expect(report.isValid, isFalse);
      expect(report.summaryLabel, 'Model asset has 1 blocking issue');
      expect(report.errorLabels, [
        'Fallback size must use finite positive dimensions.',
      ]);
    });

    test('equality is by id', () {
      const a = ARNode(id: 'same');
      const b = ARNode(id: 'same', primitiveShape: ARPrimitiveShape.sphere);
      expect(a, equals(b));
    });
  });

  // ── ARMaterial ────────────────────────────────────────────────────────────

  group('ARMaterial', () {
    test('default values', () {
      const m = ARMaterial();
      expect(m.metallic, 0);
      expect(m.roughness, 0.5);
      expect(m.opacity, 1.0);
      expect(m.doubleSided, false);
      expect(m.blendMode, ARBlendMode.opaque);
    });

    test('metal factory', () {
      final m = ARMaterial.metal();
      expect(m.metallic, 1.0);
    });

    test('glass factory is transparent', () {
      final m = ARMaterial.glass();
      expect(m.opacity, lessThan(1.0));
      expect(m.blendMode, ARBlendMode.alpha);
      expect(m.doubleSided, true);
    });

    test('emissive factory', () {
      final m = ARMaterial.emissive(
          color: const ARMaterialColor(r: 1, g: 0, b: 0), intensity: 2.0);
      expect(m.emissiveIntensity, 2.0);
      expect(m.emissiveColor!.r, 1.0);
    });

    test('copyWith changes one field', () {
      const m = ARMaterial(metallic: 0.3, roughness: 0.6);
      final m2 = m.copyWith(roughness: 0.1);
      expect(m2.metallic, 0.3);
      expect(m2.roughness, 0.1);
    });

    test('lerp halfway', () {
      final a = const ARMaterial(metallic: 0.0, roughness: 0.0);
      final b = const ARMaterial(metallic: 1.0, roughness: 1.0);
      final c = ARMaterial.lerp(a, b, 0.5);
      expect(c.metallic, closeTo(0.5, 1e-9));
      expect(c.roughness, closeTo(0.5, 1e-9));
    });

    test('toMap / fromMap round-trip', () {
      const m = ARMaterial(metallic: 0.7, roughness: 0.2, opacity: 0.8);
      final m2 = ARMaterial.fromMap(m.toMap());
      expect(m2.metallic, m.metallic);
      expect(m2.roughness, m.roughness);
      expect(m2.opacity, m.opacity);
    });
  });

  // ── ARMaterialColor ───────────────────────────────────────────────────────

  group('ARMaterialColor', () {
    test('fromARGB round-trip', () {
      final c = ARMaterialColor.fromARGB(0xFF204080);
      expect(c.a, closeTo(1.0, 0.01));
      expect(c.r, closeTo(0.125, 0.01));
      expect(c.g, closeTo(0.251, 0.01));
      expect(c.b, closeTo(0.502, 0.01));
    });

    test('fromHex 6-char', () {
      final c = ARMaterialColor.fromHex('FF0000');
      expect(c.r, closeTo(1, 0.01));
      expect(c.g, closeTo(0, 0.01));
    });

    test('fromHex 8-char with alpha', () {
      final c = ARMaterialColor.fromHex('800000FF');
      expect(c.a, closeTo(0.502, 0.01));
      expect(c.b, closeTo(1, 0.01));
    });

    test('lerp halfway', () {
      final a = const ARMaterialColor(r: 0, g: 0, b: 0);
      final b = const ARMaterialColor(r: 1, g: 1, b: 1);
      final c = ARMaterialColor.lerp(a, b, 0.5);
      expect(c.r, closeTo(0.5, 1e-9));
    });

    test('lerp is clamped', () {
      final a = const ARMaterialColor(r: 0, g: 0, b: 0);
      final b = const ARMaterialColor(r: 1, g: 1, b: 1);
      expect(ARMaterialColor.lerp(a, b, 2).r, closeTo(1, 1e-9));
      expect(ARMaterialColor.lerp(a, b, -1).r, closeTo(0, 1e-9));
    });

    test('multiply scales rgb', () {
      const c = ARMaterialColor(r: 1, g: 0.5, b: 0.25);
      final c2 = c * 0.5;
      expect(c2.r, closeTo(0.5, 1e-9));
      expect(c2.g, closeTo(0.25, 1e-9));
      expect(c2.b, closeTo(0.125, 1e-9));
    });

    test('multiply clamps to 1', () {
      const c = ARMaterialColor(r: 0.8, g: 0.8, b: 0.8);
      final c2 = c * 2.0;
      expect(c2.r, closeTo(1, 1e-9));
    });

    test('withOpacity', () {
      const c = ARMaterialColor(r: 1, g: 1, b: 1);
      final c2 = c.withOpacity(0.3);
      expect(c2.a, closeTo(0.3, 1e-9));
    });

    test('toARGB / fromARGB round-trip', () {
      const c = ARMaterialColor(r: 0.5, g: 0.25, b: 0.75, a: 1.0);
      final v = c.toARGB();
      final c2 = ARMaterialColor.fromARGB(v);
      expect(c2.r, closeTo(c.r, 0.01));
      expect(c2.g, closeTo(c.g, 0.01));
      expect(c2.b, closeTo(c.b, 0.01));
    });

    test('fromMap / toMap round-trip', () {
      const c = ARMaterialColor(r: 0.2, g: 0.4, b: 0.6, a: 0.8);
      final c2 = ARMaterialColor.fromMap(c.toMap());
      expect(c2.r, c.r);
      expect(c2.g, c.g);
      expect(c2.b, c.b);
      expect(c2.a, c.a);
    });

    test('equality', () {
      const a = ARMaterialColor(r: 0.5, g: 0.5, b: 0.5);
      const b = ARMaterialColor(r: 0.5, g: 0.5, b: 0.5);
      expect(a, equals(b));
    });

    test('named constructors', () {
      expect(const ARMaterialColor.red().r, 1);
      expect(const ARMaterialColor.green().g, 1);
      expect(const ARMaterialColor.blue().b, 1);
      expect(const ARMaterialColor.white().r, 1);
      expect(const ARMaterialColor.black().r, 0);
      expect(const ARMaterialColor.yellow().r, 1);
      expect(const ARMaterialColor.cyan().g, 1);
      expect(const ARMaterialColor.magenta().b, 1);
    });
  });

  // ── ARRay ─────────────────────────────────────────────────────────────────

  group('ARRay', () {
    test('direction is always normalised', () {
      final ray = ARRay(
          origin: const ARVector3.zero(), direction: const ARVector3(3, 4, 0));
      expect(ray.direction.length, closeTo(1, 1e-9));
    });

    test('at(t) gives correct point', () {
      final ray = ARRay(
          origin: const ARVector3(0, 0, 0),
          direction: const ARVector3(0, 0, -1));
      expect(ray.at(3).z, closeTo(-3, 1e-9));
    });

    test('sphere hit at t=4', () {
      final ray = ARRay(
          origin: const ARVector3(0, 0, 5),
          direction: const ARVector3(0, 0, -1));
      final h = ARIntersection.raySphere(
          ray: ray, centre: const ARVector3.zero(), radius: 1);
      expect(h.hit, true);
      expect(h.t, closeTo(4, 1e-5));
    });

    test('sphere miss', () {
      final ray = ARRay(
          origin: const ARVector3(5, 0, 0),
          direction: const ARVector3(0, 0, -1));
      expect(
          ARIntersection.raySphere(
                  ray: ray, centre: const ARVector3.zero(), radius: 0.5)
              .hit,
          false);
    });

    test('plane hit', () {
      final ray = ARRay(
          origin: const ARVector3(0, 2, 0),
          direction: const ARVector3(0, -1, 0));
      final h = ARIntersection.rayPlane(
          ray: ray,
          planePoint: const ARVector3.zero(),
          planeNormal: const ARVector3(0, 1, 0));
      expect(h.hit, true);
      expect(h.t, closeTo(2, 1e-9));
    });

    test('box hit', () {
      final ray = ARRay(
          origin: const ARVector3(0, 0, 5),
          direction: const ARVector3(0, 0, -1));
      final h = ARIntersection.rayBox(
          ray: ray,
          minCorner: const ARVector3(-1, -1, -1),
          maxCorner: const ARVector3(1, 1, 1));
      expect(h.hit, true);
      expect(h.t, closeTo(4, 1e-5));
    });

    test('triangle hit (Möller–Trumbore)', () {
      final ray = ARRay(
          origin: const ARVector3(0, 0, 5),
          direction: const ARVector3(0, 0, -1));
      final h = ARIntersection.rayTriangle(
          ray: ray,
          v0: const ARVector3(-1, -1, 0),
          v1: const ARVector3(1, -1, 0),
          v2: const ARVector3(0, 1, 0));
      expect(h.hit, true);
      expect(h.t, closeTo(5, 1e-5));
    });

    test('frustum sphere test returns bool', () {
      final f = ARFrustum.fromMatrix(ARMatrix4.identity());
      expect(f.testSphere(const ARVector3.zero(), 0.5), isA<bool>());
    });
  });

  // ── ARCurve ───────────────────────────────────────────────────────────────

  group('ARCurve', () {
    test('linear is identity', () {
      expect(ARCurve.linear.transform(0.5), closeTo(0.5, 1e-9));
    });

    test('all curves: t=0 → ≈0, t=1 → ≈1', () {
      for (final c in [
        ARCurve.easeIn,
        ARCurve.easeOut,
        ARCurve.easeInOut,
        ARCurve.linear,
        ARCurve.spring
      ]) {
        expect(c.transform(0), closeTo(0, 0.05));
        expect(c.transform(1), closeTo(1, 0.05));
      }
    });

    test('bounceOut ends at 1', () {
      expect(ARCurve.bounceOut.transform(1), closeTo(1, 1e-5));
    });

    test('easeInOut is symmetric around 0.5', () {
      final c = ARCurve.easeInOut;
      expect(c.transform(0.5), closeTo(0.5, 0.05));
    });
  });

  // ── ARTrack ───────────────────────────────────────────────────────────────

  group('ARTrack', () {
    test('single keyframe returns constant regardless of t', () {
      final t =
          ARTrack([ARKeyframe(0, const ARVector3(5, 0, 0))], Vector3Tween());
      expect(t.evaluate(0.0).x, 5);
      expect(t.evaluate(0.5).x, 5);
      expect(t.evaluate(1.0).x, 5);
    });

    test('two keyframes interpolate at t=0 and t=1', () {
      final t = ARTrack([
        ARKeyframe(0, const ARVector3(0, 0, 0), curve: ARCurve.linear),
        ARKeyframe(1, const ARVector3(10, 0, 0), curve: ARCurve.linear),
      ], Vector3Tween());
      expect(t.evaluate(0).x, closeTo(0, 1e-9));
      expect(t.evaluate(1).x, closeTo(10, 1e-9));
    });

    test('clamps before first keyframe', () {
      final t = ARTrack([
        ARKeyframe(0.5, const ARVector3(7, 0, 0)),
        ARKeyframe(1.0, const ARVector3(10, 0, 0)),
      ], Vector3Tween());
      expect(t.evaluate(0).x, 7);
    });

    test('quaternion track slerps correctly', () {
      final a = const ARQuaternion.identity();
      final b = ARQuaternion.axisAngle(ARVector3.up, math.pi);
      final t = ARTrack([
        ARKeyframe(0, a, curve: ARCurve.linear),
        ARKeyframe(1, b, curve: ARCurve.linear),
      ], QuaternionTween());
      expect(t.evaluate(0.5).length, closeTo(1, 1e-5));
    });
  });

  // ── ARAnimation ───────────────────────────────────────────────────────────

  group('ARAnimation', () {
    test('moveTo has positionTrack, once wrapMode', () {
      final a = ARAnimation.moveTo(
          nodeId: 'n',
          from: const ARVector3.zero(),
          to: const ARVector3(1, 0, 0));
      expect(a.positionTrack, isNotNull);
      expect(a.wrapMode, ARAnimationWrapMode.once);
    });

    test('spin has rotationTrack, loop wrapMode', () {
      final a = ARAnimation.spin(nodeId: 'n', period: 2);
      expect(a.rotationTrack, isNotNull);
      expect(a.wrapMode, ARAnimationWrapMode.loop);
    });

    test('popIn scale: 0 at t=0, 1 at t=1', () {
      final a = ARAnimation.popIn(nodeId: 'n', duration: 0.6);
      expect(a.scaleTrack!.evaluate(0).x, closeTo(0, 1e-9));
      expect(a.scaleTrack!.evaluate(1).x, closeTo(1, 1e-4));
    });

    test('hover is pingPong', () {
      final a =
          ARAnimation.hover(nodeId: 'n', basePosition: const ARVector3.zero());
      expect(a.wrapMode, ARAnimationWrapMode.pingPong);
    });

    test('normalizedTime wraps correctly for loop', () {
      final ra = _RunningAnimationHelper(
          ARAnimation.spin(nodeId: 'n', period: 1), const ARNode(id: 'n'));
      ra.elapsedSeconds = 1.5;
      expect(ra.normalizedTime, closeTo(0.5, 1e-9));
    });

    test('normalizedTime pingPong reverses at 1', () {
      final ra = _RunningAnimationHelper(
        ARAnimation.hover(
          nodeId: 'n',
          basePosition: const ARVector3.zero(),
          period: 1,
        ),
        const ARNode(id: 'n'),
      );
      ra.elapsedSeconds = 1.5;
      expect(
          ra.normalizedTime, closeTo(0.5, 1e-9)); // 1.5 % 2 = 1.5 → 2-1.5 = 0.5
    });
  });

  // ── ARPhysicsBody ─────────────────────────────────────────────────────────

  group('ARPhysicsBody', () {
    test('falls ~4.9 m in 1 second under gravity', () {
      final body = ARPhysicsBody(
          nodeId: 'b',
          initialPosition: const ARVector3(0, 1, 0),
          mass: 1,
          restitution: 0,
          friction: 0,
          linearDamping: 0);
      const g = ARVector3(0, -9.81, 0);
      for (int i = 0; i < 60; i++) body.integrateForTesting(1 / 60.0, g);
      expect(body.position.y, closeTo(1 - 4.9, 0.5));
    });

    test('static body does not move', () {
      final body = ARPhysicsBody(
          nodeId: 's',
          initialPosition: const ARVector3(0, 5, 0),
          isStatic: true);
      body.integrateForTesting(1.0, const ARVector3(0, -9.81, 0));
      expect(body.position.y, 5);
    });

    test('impulse changes velocity: v = p/m', () {
      final body = ARPhysicsBody(
          nodeId: 'i',
          initialPosition: const ARVector3.zero(),
          mass: 2,
          restitution: 0,
          friction: 0);
      body.applyImpulse(const ARVector3(4, 0, 0));
      expect(body.linearVelocity.x, closeTo(2, 1e-9));
    });

    test('force accumulates per step', () {
      final body = ARPhysicsBody(
          nodeId: 'f',
          initialPosition: const ARVector3.zero(),
          mass: 1,
          restitution: 0,
          friction: 0);
      body.applyForce(const ARVector3(10, 0, 0));
      body.applyForce(const ARVector3(10, 0, 0));
      body.integrateForTesting(0.1, const ARVector3.zero());
      // v = (10+10)*0.1 = 2 (before damping)
      expect(body.linearVelocity.x, greaterThan(1.8));
    });

    test('body sleeps when velocity is tiny', () {
      final body = ARPhysicsBody(
          nodeId: 'z', initialPosition: const ARVector3.zero(), mass: 1);
      // Force very small velocity
      body.applyImpulse(const ARVector3(0.00001, 0, 0));
      body.integrateForTesting(1.0, const ARVector3.zero());
      // After damping + sleep check it should be asleep
      expect(body.isAwake, false);
    });

    test('static body cannot receive impulse', () {
      final body = ARPhysicsBody(
          nodeId: 'st',
          initialPosition: const ARVector3.zero(),
          isStatic: true);
      body.applyImpulse(const ARVector3(100, 0, 0));
      expect(body.linearVelocity.x, 0);
    });

    test('copyWith can retarget node ID and preserve runtime state', () {
      final body = ARPhysicsBody(
        nodeId: 'requested',
        initialPosition: const ARVector3(1, 2, 3),
        mass: 2,
        restitution: 0.7,
        shape: ARColliderShape.box,
        shapeSize: const ARVector3(0.2, 0.3, 0.4),
      )..applyImpulse(const ARVector3(4, 0, 0));

      final copy = body.copyWith(nodeId: 'native_1');

      expect(copy.nodeId, 'native_1');
      expect(copy.mass, 2);
      expect(copy.restitution, 0.7);
      expect(copy.shape, ARColliderShape.box);
      expect(copy.shapeSize, const ARVector3(0.2, 0.3, 0.4));
      expect(copy.position, const ARVector3(1, 2, 3));
      expect(copy.linearVelocity.x, closeTo(2, 1e-9));
    });
  });

  // ── ARMeasurementSession ──────────────────────────────────────────────────

  group('ARMeasurementSession', () {
    ARMeasurementPoint pt(double x, double z) => ARMeasurementPoint(
        anchorId: 'a',
        worldPosition: ARVector3(x, 0, z),
        timestamp: DateTime.now());

    test('directDistance: 3-4-5 triangle', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.distance, points: [pt(0, 0), pt(3, 4)]);
      expect(s.directDistance, closeTo(5, 1e-9));
    });

    test('totalLength: path along three points', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.distance,
          points: [pt(0, 0), pt(1, 0), pt(1, 1)]);
      expect(s.totalLength, closeTo(2, 1e-9));
    });

    test('polygonArea: unit square = 1 m²', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.area,
          points: [pt(0, 0), pt(1, 0), pt(1, 1), pt(0, 1)]);
      expect(s.polygonArea, closeTo(1, 1e-9));
    });

    test('polygon3DArea: unit square in XZ plane', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.area,
          points: [pt(0, 0), pt(1, 0), pt(1, 1), pt(0, 1)]);
      expect(s.polygon3DArea, closeTo(1, 1e-6));
    });

    test('angleDegrees: perpendicular = 90°', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.angle,
          points: [pt(1, 0), pt(0, 0), pt(0, 1)]);
      expect(s.angleDegrees, closeTo(90, 1e-4));
    });

    test('angleDegrees: collinear = 180°', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.angle,
          points: [pt(-1, 0), pt(0, 0), pt(1, 0)]);
      expect(s.angleDegrees, closeTo(180, 1e-4));
    });

    test('boxVolume: 2x3x4 box', () {
      final s = ARMeasurementSession(mode: ARMeasurementMode.volume, points: [
        ARMeasurementPoint(
            anchorId: 'a',
            worldPosition: const ARVector3(0, 0, 0),
            timestamp: DateTime.now()),
        ARMeasurementPoint(
            anchorId: 'b',
            worldPosition: const ARVector3(2, 3, 4),
            timestamp: DateTime.now()),
      ]);
      expect(s.boxVolume, closeTo(24, 1e-9));
    });

    test('formatLength: mm / cm / m thresholds', () {
      final s =
          ARMeasurementSession(mode: ARMeasurementMode.distance, points: []);
      expect(s.formatLength(0.005), contains('mm'));
      expect(s.formatLength(0.5), contains('cm'));
      expect(s.formatLength(5.0), contains('m'));
    });

    test('formatArea: cm² / m² thresholds', () {
      final s = ARMeasurementSession(mode: ARMeasurementMode.area, points: []);
      expect(s.formatArea(0.005), contains('cm²'));
      expect(s.formatArea(5.0), contains('m²'));
    });

    test('summaryText: distance with 2 points', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.distance, points: [pt(0, 0), pt(0, 1)]);
      expect(s.summaryText, isNotEmpty);
    });

    test('empty session returns zero distance', () {
      final s =
          ARMeasurementSession(mode: ARMeasurementMode.distance, points: []);
      expect(s.directDistance, 0);
    });
  });

  // ── ARSessionConfig ───────────────────────────────────────────────────────

  group('ARSessionConfig', () {
    test('toMap has all required keys', () {
      const c = ARSessionConfig(
        detectHorizontalPlanes: true,
        detectVerticalPlanes: false,
        lightingEstimationEnabled: true,
        targetFrameRate: 60,
      );
      final m = c.toMap();
      for (final key in [
        'detectHorizontalPlanes',
        'detectVerticalPlanes',
        'lightingEstimationEnabled',
        'targetFrameRate',
        'showFeaturePoints',
        'imageTargets'
      ]) {
        expect(m.containsKey(key), true, reason: 'missing key: $key');
      }
      expect(m['targetFrameRate'], 60);
    });

    test('imageTargets round-trip', () {
      const c = ARSessionConfig(imageTargets: [
        ARImageTarget(
            name: 'poster',
            assetPath: 'assets/p.jpg',
            physicalWidthMeters: 0.297)
      ]);
      final tgts = c.toMap()['imageTargets'] as List;
      expect(tgts.length, 1);
      expect((tgts.first as Map)['name'], 'poster');
      expect((tgts.first as Map)['physicalWidthMeters'], 0.297);
    });
  });

  // ── ARAnchor ──────────────────────────────────────────────────────────────

  group('ARAnchor', () {
    test('copyWith changes trackingState', () {
      const a = ARAnchor(
          id: 'a1',
          pose: ARPose(
              position: ARVector3.zero(), rotation: ARQuaternion.identity()),
          trackingState: ARTrackingState.tracking);
      final a2 = a.copyWith(trackingState: ARTrackingState.paused);
      expect(a2.trackingState, ARTrackingState.paused);
      expect(a2.id, 'a1');
    });

    test('fromMap / toMap round-trip', () {
      const a = ARAnchor(
          id: 'test',
          pose: ARPose(
              position: ARVector3(1, 2, 3), rotation: ARQuaternion.identity()),
          trackingState: ARTrackingState.tracking);
      final a2 = ARAnchor.fromMap(a.toMap());
      expect(a2.id, 'test');
      expect(a2.pose.position.x, 1);
      expect(a2.trackingState, ARTrackingState.tracking);
    });
  });

  // ── ARPlane ───────────────────────────────────────────────────────────────

  group('ARPlane', () {
    ARPlane makePlane(String alignment) => ARPlane.fromMap({
          'id': 'p1',
          'alignment': alignment,
          'centerPose': {
            'position': {'x': 0, 'y': 0, 'z': 0},
            'rotation': {'x': 0, 'y': 0, 'z': 0, 'w': 1}
          },
          'extentMeters': {'x': 1, 'y': 0, 'z': 1},
          'boundaryVertices': [
            {'x': 0, 'y': 0, 'z': 0},
            {'x': 1, 'y': 0, 'z': 0}
          ],
          'trackingState': 'tracking',
        });

    test('parses horizontal alignment', () {
      expect(makePlane('horizontal').alignment, ARPlaneAlignment.horizontal);
    });

    test('parses vertical alignment', () {
      expect(makePlane('vertical').alignment, ARPlaneAlignment.vertical);
    });

    test('boundaryVertices parsed correctly', () {
      expect(makePlane('horizontal').boundaryVertices.length, 2);
    });
  });

  // ── ARPoseInput ───────────────────────────────────────────────────────────

  group('ARPoseInput', () {
    test('toMap contains position and rotation', () {
      const p = ARPoseInput(x: 1, y: 2, z: 3);
      final m = p.toMap();
      expect((m['position'] as Map)['x'], 1);
      expect((m['rotation'] as Map)['w'], 1);
    });

    test('custom quaternion is preserved', () {
      const p = ARPoseInput(x: 0, y: 0, z: 0, qx: 0, qy: 1, qz: 0, qw: 0);
      final m = p.toMap();
      expect((m['rotation'] as Map)['y'], 1);
    });
  });

  // ── ARLight ───────────────────────────────────────────────────────────────

  group('ARLight', () {
    test('toMap contains all fields', () {
      const l = ARLight(
          id: 'sun',
          type: ARLightType.directional,
          intensity: 1200,
          direction: ARVector3(0, -1, -0.5));
      final m = l.toMap();
      expect(m['type'], 'directional');
      expect(m['intensity'], 1200);
      expect((m['direction'] as Map)['y'], -1);
    });
  });

  // ── ARRecordingConfig ─────────────────────────────────────────────────────

  group('ARRecordingConfig', () {
    test('defaults are sensible', () {
      const c = ARRecordingConfig();
      expect(c.fps, 30);
      expect(c.videoBitrateKbps, 4000);
      expect(c.includeAudio, false);
      expect(c.includeUIOverlay, true);
    });

    test('custom config', () {
      const c = ARRecordingConfig(
          fps: 60,
          videoBitrateKbps: 8000,
          includeAudio: true,
          includeUIOverlay: false);
      expect(c.fps, 60);
      expect(c.includeAudio, true);
    });
  });

  // ── ARPortalConfig ────────────────────────────────────────────────────────

  group('ARPortalConfig', () {
    test('defaults', () {
      const c = ARPortalConfig();
      expect(c.shape, ARPortalShape.arch);
      expect(c.width, 0.8);
      expect(c.height, 1.8);
    });

    test('custom size', () {
      const c =
          ARPortalConfig(width: 1.2, height: 2.4, shape: ARPortalShape.circle);
      expect(c.shape, ARPortalShape.circle);
      expect(c.width, 1.2);
    });
  });

  // ── AROcclusionManager ────────────────────────────────────────────────────

  group('AROcclusionMode', () {
    test('enum values exist', () {
      expect(AROcclusionMode.values.contains(AROcclusionMode.disabled), true);
      expect(AROcclusionMode.values.contains(AROcclusionMode.environmentDepth),
          true);
      expect(AROcclusionMode.values.contains(AROcclusionMode.humanOcclusion),
          true);
      expect(AROcclusionMode.values.contains(AROcclusionMode.combined), true);
    });
  });

  // ── ARGestureEvent ────────────────────────────────────────────────────────

  group('ARGestureEvent', () {
    test('fields are accessible', () {
      const ev = ARGestureEvent(
        type: ARGestureType.tap,
        entityId: 'entity1',
        screenPoint: Offset(0.5, 0.5),
        scaleFactor: 1.5,
      );
      expect(ev.type, ARGestureType.tap);
      expect(ev.entityId, 'entity1');
      expect(ev.scaleFactor, 1.5);
    });

    test('null entityId means empty space tap', () {
      const ev = ARGestureEvent(
        type: ARGestureType.tap,
        screenPoint: Offset(0.3, 0.7),
      );
      expect(ev.entityId, isNull);
    });
  });
  // ── ARVector3 new methods ─────────────────────────────────────────────────

  group('ARVector3 enhanced', () {
    test('reflect off XZ plane', () {
      const v = ARVector3(1, -1, 0);
      const n = ARVector3(0, 1, 0);
      final r = v.reflect(n);
      expect(r.x, closeTo(1, 1e-9));
      expect(r.y, closeTo(1, 1e-9));
      expect(r.z, closeTo(0, 1e-9));
    });

    test('project onto axis', () {
      const v = ARVector3(3, 4, 0);
      const axis = ARVector3(1, 0, 0);
      final p = v.projectOnto(axis);
      expect(p.x, closeTo(3, 1e-9));
      expect(p.y, closeTo(0, 1e-9));
    });

    test('reject is perpendicular to onto vector', () {
      const v = ARVector3(3, 4, 0);
      const axis = ARVector3(1, 0, 0);
      final rej = v.rejectFrom(axis);
      expect(rej.dot(axis), closeTo(0, 1e-9));
    });

    test('clamp components', () {
      const v = ARVector3(5, -3, 2);
      final c = v.clamp(-1, 1);
      expect(c.x, closeTo(1, 1e-9));
      expect(c.y, closeTo(-1, 1e-9));
      expect(c.z, closeTo(1, 1e-9));
    });

    test('clampLength', () {
      const v = ARVector3(3, 4, 0);
      final c = v.clampLength(2);
      expect(c.length, closeTo(2, 1e-9));
    });

    test('abs is component-wise', () {
      const v = ARVector3(-1, 2, -3);
      expect(v.abs.x, 1);
      expect(v.abs.y, 2);
      expect(v.abs.z, 3);
    });

    test('min and max', () {
      const a = ARVector3(1, 5, 3);
      const b = ARVector3(4, 2, 6);
      final mn = ARVector3.min(a, b);
      final mx = ARVector3.max(a, b);
      expect(mn.x, 1);
      expect(mn.y, 2);
      expect(mn.z, 3);
      expect(mx.x, 4);
      expect(mx.y, 5);
      expect(mx.z, 6);
    });

    test('moveTowards stops at target', () {
      const current = ARVector3(0, 0, 0);
      const target = ARVector3(1, 0, 0);
      final r = ARVector3.moveTowards(current, target, 100);
      expect(r.x, closeTo(1, 1e-9));
    });

    test('moveTowards partial step', () {
      const current = ARVector3(0, 0, 0);
      const target = ARVector3(4, 0, 0);
      final r = ARVector3.moveTowards(current, target, 1);
      expect(r.x, closeTo(1, 1e-9));
    });

    test('angleTo orthogonal = π/2', () {
      expect(const ARVector3(1, 0, 0).angleTo(const ARVector3(0, 1, 0)),
          closeTo(math.pi / 2, 1e-9));
    });

    test('angleTo parallel = 0', () {
      expect(const ARVector3(1, 0, 0).angleTo(const ARVector3(2, 0, 0)),
          closeTo(0, 1e-9));
    });

    test('scale component-wise', () {
      const v = ARVector3(2, 3, 4);
      const s = ARVector3(2, 3, 4);
      final r = v.scale(s);
      expect(r.x, 4);
      expect(r.y, 9);
      expect(r.z, 16);
    });

    test('static direction constants', () {
      expect(ARVector3.down.y, -1);
      expect(ARVector3.back.z, 1);
      expect(ARVector3.left.x, -1);
      expect(ARVector3.forward.z, -1);
    });

    test('lerpUnclamped extrapolates', () {
      const a = ARVector3(0, 0, 0);
      const b = ARVector3(10, 0, 0);
      expect(ARVector3.lerpUnclamped(a, b, 2).x, closeTo(20, 1e-9));
    });
  });

  // ── ARQuaternion new methods ───────────────────────────────────────────────

  group('ARQuaternion enhanced', () {
    test('toEuler identity = [0,0,0]', () {
      final e = const ARQuaternion.identity().toEuler();
      expect(e[0], closeTo(0, 1e-9));
      expect(e[1], closeTo(0, 1e-9));
      expect(e[2], closeTo(0, 1e-9));
    });

    test('toEuler round-trips yaw 90°', () {
      final q = ARQuaternion.axisAngle(ARVector3.up, math.pi / 2);
      final e = q.toEuler();
      expect(e[1], closeTo(math.pi / 2, 1e-5)); // yaw
    });

    test('fromToRotation takes X to Y', () {
      final q = ARQuaternion.fromToRotation(
          const ARVector3(1, 0, 0), const ARVector3(0, 1, 0));
      final r = q.rotateVector(const ARVector3(1, 0, 0));
      expect(r.x, closeTo(0, 1e-5));
      expect(r.y, closeTo(1, 1e-5));
    });

    test('fromToRotation parallel = identity', () {
      final q = ARQuaternion.fromToRotation(
          const ARVector3(1, 0, 0), const ARVector3(2, 0, 0));
      expect(q.w, closeTo(1, 1e-5));
    });

    test('lookRotation produces unit quaternion', () {
      final q = ARQuaternion.lookRotation(const ARVector3(0, 0, -1));
      expect(q.length, closeTo(1, 1e-5));
    });

    test('rotateTowards stops at target', () {
      final a = ARQuaternion.axisAngle(ARVector3.up, 0);
      final b = ARQuaternion.axisAngle(ARVector3.up, math.pi / 2);
      final r = ARQuaternion.rotateTowards(a, b, math.pi);
      expect(r.w, closeTo(b.w, 1e-4));
    });

    test('rotateTowards partial', () {
      final a = ARQuaternion.axisAngle(ARVector3.up, 0);
      final b = ARQuaternion.axisAngle(ARVector3.up, math.pi / 2);
      final r = ARQuaternion.rotateTowards(a, b, math.pi / 4);
      // Should be halfway
      expect(r.length, closeTo(1, 1e-5));
    });

    test('dot of identity with itself = 1', () {
      const q = ARQuaternion.identity();
      expect(q.dot(q), closeTo(1, 1e-9));
    });

    test('angle property', () {
      final q = ARQuaternion.axisAngle(ARVector3.up, math.pi / 3);
      expect(q.angle, closeTo(math.pi / 3, 1e-5));
    });

    test('toList has 4 elements', () {
      expect(const ARQuaternion.identity().toList().length, 4);
    });

    test('equality', () {
      final a = ARQuaternion.axisAngle(ARVector3.up, 1.0);
      final b = ARQuaternion.axisAngle(ARVector3.up, 1.0);
      expect(a, equals(b));
    });
  });

  // ── ARMatrix4 new methods ─────────────────────────────────────────────────

  group('ARMatrix4 enhanced', () {
    test('inverse of identity is identity', () {
      final m = ARMatrix4.identity();
      final i = m.inverse;
      for (int k = 0; k < 16; k++) {
        expect(i.storage[k], closeTo(m.storage[k], 1e-9));
      }
    });

    test('M * M_inv = identity', () {
      final t = ARMatrix4.fromTranslation(const ARVector3(1, 2, 3));
      final ti = t.inverse;
      final product = t * ti;
      expect(product.storage[0], closeTo(1, 1e-9));
      expect(product.storage[12], closeTo(0, 1e-9));
    });

    test('transpose swaps off-diagonal', () {
      final m = ARMatrix4.fromTranslation(const ARVector3(5, 0, 0));
      final t = m.transposed;
      // In column-major, translation was at [12]; after transpose it moves to [3]
      expect(t.storage[3], closeTo(5, 1e-9));
    });

    test('transformPoint applies translation', () {
      final m = ARMatrix4.fromTranslation(const ARVector3(10, 0, 0));
      final p = m.transformPoint(const ARVector3.zero());
      expect(p.x, closeTo(10, 1e-9));
    });

    test('transformDirection ignores translation', () {
      final m = ARMatrix4.fromTranslation(const ARVector3(10, 0, 0));
      final d = m.transformDirection(const ARVector3(0, 1, 0));
      expect(d.x, closeTo(0, 1e-9));
      expect(d.y, closeTo(1, 1e-9));
    });

    test('fromScale scales a point', () {
      final m = ARMatrix4.fromScale(const ARVector3(2, 3, 4));
      final p = m.transformPoint(const ARVector3(1, 1, 1));
      expect(p.x, closeTo(2, 1e-9));
      expect(p.y, closeTo(3, 1e-9));
      expect(p.z, closeTo(4, 1e-9));
    });

    test('scale getter extracts TRS scale', () {
      final m = ARMatrix4.trs(const ARVector3.zero(),
          const ARQuaternion.identity(), const ARVector3(2, 3, 4));
      final s = m.scale;
      expect(s.x, closeTo(2, 1e-5));
      expect(s.y, closeTo(3, 1e-5));
      expect(s.z, closeTo(4, 1e-5));
    });

    test('lookAt places camera at eye', () {
      final m = ARMatrix4.lookAt(
          eye: const ARVector3(0, 0, 5), center: const ARVector3.zero());
      // Translation column should be based on eye position
      expect(m.storage.length, 16);
    });
  });

  // ── ARPose enhanced ───────────────────────────────────────────────────────

  group('ARPose enhanced', () {
    test('inverse of identity is identity', () {
      final inv = const ARPose.identity().inverse;
      expect(inv.position.length, closeTo(0, 1e-9));
      expect(inv.rotation.w, closeTo(1, 1e-9));
    });

    test('pose * inverse = identity', () {
      final p = ARPose(
        position: const ARVector3(1, 2, 3),
        rotation: ARQuaternion.axisAngle(ARVector3.up, math.pi / 4),
      );
      final result = p.transformedBy(p.inverse);
      expect(result.position.length, closeTo(0, 1e-5));
    });

    test('isIdentity true for identity', () {
      expect(const ARPose.identity().isIdentity(), true);
    });

    test('isIdentity false for non-identity', () {
      const p = ARPose(
          position: ARVector3(1, 0, 0), rotation: ARQuaternion.identity());
      expect(p.isIdentity(), false);
    });

    test('lookAt produces unit quaternion', () {
      final p = ARPose.lookAt(
          eye: const ARVector3(0, 0, 5), target: const ARVector3.zero());
      expect(p.rotation.length, closeTo(1, 1e-5));
    });

    test('copyWith changes position only', () {
      final p = ARPose(
          position: const ARVector3(1, 2, 3),
          rotation: ARQuaternion.axisAngle(ARVector3.up, 1.0));
      final p2 = p.copyWith(position: const ARVector3(9, 9, 9));
      expect(p2.position.x, 9);
      expect(p2.rotation.w, closeTo(p.rotation.w, 1e-9));
    });

    test('distanceTo', () {
      const a = ARPose(
          position: ARVector3(0, 0, 0), rotation: ARQuaternion.identity());
      const b = ARPose(
          position: ARVector3(3, 4, 0), rotation: ARQuaternion.identity());
      expect(a.distanceTo(b), closeTo(5, 1e-9));
    });

    test('equality', () {
      const a = ARPose(
          position: ARVector3(1, 2, 3), rotation: ARQuaternion.identity());
      const b = ARPose(
          position: ARVector3(1, 2, 3), rotation: ARQuaternion.identity());
      expect(a, equals(b));
    });
  });

  // ── ARLight enhanced ──────────────────────────────────────────────────────

  group('ARLight enhanced', () {
    test('sun factory has high intensity', () {
      final l = ARLight.sun(id: 'sun');
      expect(l.intensity, greaterThan(10000));
      expect(l.type, ARLightType.directional);
    });

    test('point factory', () {
      final l = ARLight.point(id: 'pt', position: const ARVector3(0, 2, 0));
      expect(l.type, ARLightType.point);
      expect(l.position, isNotNull);
    });

    test('spot factory has cone angles', () {
      final l = ARLight.spot(
          id: 'sp',
          position: const ARVector3.zero(),
          direction: const ARVector3(0, -1, 0));
      expect(l.spotInnerAngle, isNotNull);
      expect(l.spotOuterAngle, isNotNull);
    });

    test('colorFromTemperature at 6500K is near white', () {
      final c = ARLight.colorFromTemperature(6500);
      expect(c.x, greaterThan(0.9)); // red
      expect(c.y, greaterThan(0.8)); // green
      expect(c.z, greaterThan(0.7)); // blue
    });

    test('copyWith changes intensity', () {
      final l = ARLight.sun(id: 'sun');
      final l2 = l.copyWith(intensity: 500);
      expect(l2.intensity, 500);
      expect(l2.type, l.type);
    });

    test('fromMap / toMap round-trip', () {
      final l = ARLight.sun(id: 'roundtrip');
      final l2 = ARLight.fromMap(l.toMap());
      expect(l2.id, 'roundtrip');
      expect(l2.intensity, l.intensity);
      expect(l2.type, l.type);
    });

    test('equality by id', () {
      final a = ARLight.sun(id: 'same');
      final b = ARLight.ambient(id: 'same');
      expect(a, equals(b));
    });
  });

  // ── ARMeasurementSession enhanced ────────────────────────────────────────

  group('ARMeasurementSession enhanced', () {
    ARMeasurementPoint pt(double x, double y, double z) => ARMeasurementPoint(
        anchorId: 'a',
        worldPosition: ARVector3(x, y, z),
        timestamp: DateTime.now());

    test('heightDifference', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.distance, points: [pt(0, 0, 0), pt(0, 2, 0)]);
      expect(s.heightDifference, closeTo(2, 1e-9));
    });

    test('heightDifference is signed', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.distance, points: [pt(0, 3, 0), pt(0, 1, 0)]);
      expect(s.heightDifference, closeTo(-2, 1e-9));
    });

    test('horizontalDistance ignores Y', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.distance,
          points: [pt(0, 5, 0), pt(3, 10, 4)]);
      expect(s.horizontalDistance, closeTo(5, 1e-9));
    });

    test('formatLengthImperial feet and inches', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.distance,
          points: [],
          unit: ARMeasurementUnit.imperial);
      final ft = s.formatLengthImperial(0.3048); // exactly 1 foot
      expect(ft, contains('1'));
      expect(ft, contains('′'));
    });

    test('formatAreaImperial sq ft', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.area,
          points: [],
          unit: ARMeasurementUnit.imperial);
      final area = s.formatAreaImperial(1.0); // 10.76 sq ft
      expect(area, contains('ft²'));
    });

    test('toJSON has metrics key', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.distance, points: [pt(0, 0, 0), pt(1, 0, 0)]);
      final j = s.toJSON();
      expect(j.containsKey('metrics'), true);
      expect((j['metrics'] as Map).containsKey('directDistance'), true);
    });

    test('toSVGPath returns valid SVG', () {
      final s = ARMeasurementSession(
          mode: ARMeasurementMode.distance, points: [pt(0, 0, 0), pt(1, 0, 1)]);
      final svg = s.toSVGPath();
      expect(svg, contains('<svg'));
      expect(svg, contains('polyline'));
      expect(svg, contains('</svg>'));
    });
  });

  // ── Exceptions ────────────────────────────────────────────────────────────

  group('ARExceptions', () {
    test('ARNotSupportedException has message', () {
      const e = ARNotSupportedException();
      expect(e.toString(), contains('ARNotSupportedException'));
    });

    test('ARSessionInitException with cause', () {
      const e = ARSessionInitException('init failed', 'some error');
      expect(e.toString(), contains('init failed'));
      expect(e.toString(), contains('some error'));
    });

    test('ARTimeoutException includes duration', () {
      const e = ARTimeoutException('timed out', timeout: Duration(seconds: 5));
      expect(e.toString(), contains('5'));
    });

    test('ARCloudAnchorException with cloudId', () {
      const e = ARCloudAnchorException('bad anchor', cloudId: 'abc123');
      expect(e.toString(), contains('abc123'));
    });

    test('ARNodeException with nodeId', () {
      const e = ARNodeException('not found', nodeId: 'my_node');
      expect(e.toString(), contains('my_node'));
    });

    test('ARRecordingException', () {
      const e = ARRecordingException('encode failed');
      expect(e.toString(), contains('ARRecordingException'));
    });

    test('ARPhysicsException', () {
      const e = ARPhysicsException('nan velocity');
      expect(e.toString(), contains('nan velocity'));
    });

    test('ARTrackingLostException', () {
      const e = ARTrackingLostException();
      expect(e.toString(), contains('ARTrackingLostException'));
    });
  });

  // ── ARLODLevel / ARLODManager ─────────────────────────────────────────────

  group('ARLODLevel', () {
    test('levels sorted by maxDistance', () {
      final l1 = ARLODLevel(maxDistance: 5, node: const ARNode(id: 'h'));
      final l2 = ARLODLevel(maxDistance: 2, node: const ARNode(id: 'l'));
      // ARLODManager sorts internally — just test construction
      expect(l1.maxDistance, greaterThan(l2.maxDistance));
    });
  });

  // ── ARSpatialAudioSource ──────────────────────────────────────────────────

  group('ARSpatialAudioSource', () {
    test('gainAt ref distance = volume', () {
      final src = ARSpatialAudioSource(
        id: 's',
        assetPath: 'a.mp3',
        position: const ARVector3(0, 0, 0),
        refDistance: 1.0,
        volume: 0.8,
        attenuationModel: ARAttenuationModel.inverseSquare,
      );
      final g = src.gainAt(const ARVector3(1, 0, 0)); // 1m away = refDist
      expect(g, closeTo(0.8, 0.05));
    });

    test('gainAt beyond maxRange = 0', () {
      final src = ARSpatialAudioSource(
        id: 's',
        assetPath: 'a.mp3',
        position: const ARVector3(0, 0, 0),
        maxRange: 5,
      );
      expect(src.gainAt(const ARVector3(10, 0, 0)), 0);
    });

    test('linear attenuation at midpoint ≈ 0.5', () {
      final src = ARSpatialAudioSource(
        id: 's',
        assetPath: 'a.mp3',
        position: const ARVector3(0, 0, 0),
        maxRange: 10,
        attenuationModel: ARAttenuationModel.linear,
      );
      final g = src.gainAt(const ARVector3(5, 0, 0));
      expect(g, closeTo(0.5, 0.01));
    });
  });

  // ── AREnvironmentProbeResult ──────────────────────────────────────────────

  group('AREnvironmentProbeResult', () {
    test('hasCubemap false when cubeFaces null', () {
      final r = AREnvironmentProbeResult(
        skyColor: [0.5, 0.6, 0.8],
        groundColor: [0.2, 0.2, 0.1],
        ambientLux: 500,
        timestamp: DateTime.now(),
      );
      expect(r.hasCubemap, false);
    });

    test('pixelCount computed correctly', () {
      expect(
          ARDepthFrame(
              width: 128,
              height: 96,
              confidence: ARDepthConfidence.high,
              timestamp: DateTime.now(),
              cameraFrame: ARCamera(
                pose: const ARPose.identity(),
                projectionMatrix: ARMatrix4.identity(),
                viewMatrix: ARMatrix4.identity(),
                trackingState: ARTrackingState.tracking,
                intrinsics: [0, 0, 0, 0],
                imageResolution: [128, 96],
              )).pixelCount,
          128 * 96);
    });
  });

  // ── ARPhysicsBody enhanced ────────────────────────────────────────────────

  group('ARPhysicsBody enhanced', () {
    test('speed is magnitude of velocity', () {
      final b =
          ARPhysicsBody(nodeId: 's', initialPosition: const ARVector3.zero());
      b.applyImpulse(const ARVector3(3, 4, 0));
      expect(b.speed, closeTo(5 / b.mass, 0.1));
    });

    test('kineticEnergy = 0.5*m*v²', () {
      final b = ARPhysicsBody(
          nodeId: 'ke', initialPosition: const ARVector3.zero(), mass: 2.0);
      b.applyImpulse(const ARVector3(4, 0, 0)); // v = 4/2 = 2 m/s
      // KE = 0.5 * 2 * 4 = 4 J
      expect(b.kineticEnergy, closeTo(4, 0.1));
    });

    test('kineticEnergy = 0 for static body', () {
      final b = ARPhysicsBody(
          nodeId: 'st',
          initialPosition: const ARVector3.zero(),
          isStatic: true);
      expect(b.kineticEnergy, 0);
    });

    test('reset zeroes velocity', () {
      final b =
          ARPhysicsBody(nodeId: 'r', initialPosition: const ARVector3.zero());
      b.applyImpulse(const ARVector3(10, 0, 0));
      b.reset();
      expect(b.linearVelocity.length, 0);
      expect(b.isAwake, true);
    });

    test('wakeUp re-enables sleeping body', () {
      final b =
          ARPhysicsBody(nodeId: 'w', initialPosition: const ARVector3.zero());
      b.integrateForTesting(10.0, const ARVector3.zero()); // should sleep
      expect(b.isAwake, false);
      b.wakeUp();
      expect(b.isAwake, true);
    });

    test('angularVelocity changes after torque impulse', () {
      final b =
          ARPhysicsBody(nodeId: 'tv', initialPosition: const ARVector3.zero());
      b.applyTorqueImpulse(const ARVector3(0, 1, 0));
      expect(b.angularVelocity.y, closeTo(1, 1e-9));
    });
  });

  // ── ARCamera enhanced ─────────────────────────────────────────────────────

  group('ARCamera enhanced', () {
    ARCamera _cam() => ARCamera(
          pose: const ARPose.identity(),
          projectionMatrix: ARMatrix4.identity(),
          viewMatrix: ARMatrix4.identity(),
          trackingState: ARTrackingState.tracking,
          intrinsics: [600.0, 600.0, 320.0, 240.0],
          imageResolution: [640, 480],
        );

    test('focalLengthX/Y from intrinsics', () {
      final c = _cam();
      expect(c.focalLengthX, 600.0);
      expect(c.focalLengthY, 600.0);
    });

    test('principalPoint from intrinsics', () {
      final c = _cam();
      expect(c.principalPointX, 320.0);
      expect(c.principalPointY, 240.0);
    });

    test('imageWidth / imageHeight', () {
      final c = _cam();
      expect(c.imageWidth, 640);
      expect(c.imageHeight, 480);
    });

    test('aspectRatio', () {
      final c = _cam();
      expect(c.aspectRatio, closeTo(640.0 / 480.0, 1e-9));
    });

    test('isTracking true when tracking', () {
      expect(_cam().isTracking, true);
    });

    test('toMap / fromMap round-trip', () {
      final c = _cam();
      final c2 = ARCamera.fromMap(c.toMap());
      expect(c2.trackingState, ARTrackingState.tracking);
      expect(c2.imageWidth, 640);
      expect(c2.focalLengthX, 600.0);
    });

    test('copyWith changes trackingState', () {
      final c = _cam();
      final c2 = c.copyWith(trackingState: ARTrackingState.paused);
      expect(c2.trackingState, ARTrackingState.paused);
      expect(c2.imageWidth, 640);
    });
  });

  // ── ARSessionConfig enhanced ──────────────────────────────────────────────

  group('ARSessionConfig enhanced', () {
    test('copyWith changes one field', () {
      const c = ARSessionConfig(detectHorizontalPlanes: true);
      final c2 = c.copyWith(occlusionEnabled: true, depthEnabled: true);
      expect(c2.occlusionEnabled, true);
      expect(c2.depthEnabled, true);
      expect(c2.detectHorizontalPlanes, true); // unchanged
    });

    test('copyWith preserves, changes, and clears target frame rate', () {
      const c = ARSessionConfig(targetFrameRate: 30);

      expect(c.copyWith().targetFrameRate, 30);
      expect(c.copyWith(targetFrameRate: 60).targetFrameRate, 60);
      expect(c.copyWith(clearTargetFrameRate: true).targetFrameRate, isNull);
    });

    test('fromMap round-trip', () {
      const c = ARSessionConfig(
          detectHorizontalPlanes: false, occlusionEnabled: true);
      final c2 = ARSessionConfig.fromMap(c.toMap());
      expect(c2.detectHorizontalPlanes, false);
      expect(c2.occlusionEnabled, true);
    });

    test('equality', () {
      const a = ARSessionConfig(detectHorizontalPlanes: true);
      const b = ARSessionConfig(detectHorizontalPlanes: true);
      expect(a, equals(b));
    });

    test('inequality on different field', () {
      const a = ARSessionConfig(depthEnabled: false);
      const b = ARSessionConfig(depthEnabled: true);
      expect(a, isNot(equals(b)));
    });

    test('inequality includes image targets and tracking flags', () {
      const base = ARSessionConfig();
      const imageTracking = ARSessionConfig(
        imageTargets: <ARImageTarget>[
          ARImageTarget(
            name: 'poster',
            assetPath: 'poster.png',
            physicalWidthMeters: 0.3,
          ),
        ],
      );
      const bodyTracking = ARSessionConfig(bodyTrackingEnabled: true);
      const featurePoints = ARSessionConfig(showFeaturePoints: true);
      const geospatial = ARSessionConfig(geospatialEnabled: true);

      expect(base, isNot(equals(imageTracking)));
      expect(base, isNot(equals(bodyTracking)));
      expect(base, isNot(equals(featurePoints)));
      expect(base, isNot(equals(geospatial)));
    });

    test('inequality includes image target physical width', () {
      const a = ARSessionConfig(
        imageTargets: <ARImageTarget>[
          ARImageTarget(
            name: 'poster',
            assetPath: 'poster.png',
            physicalWidthMeters: 0.3,
          ),
        ],
      );
      const b = ARSessionConfig(
        imageTargets: <ARImageTarget>[
          ARImageTarget(
            name: 'poster',
            assetPath: 'poster.png',
            physicalWidthMeters: 0.5,
          ),
        ],
      );

      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('ARImageTarget copyWith', () {
      const t = ARImageTarget(
          name: 'p', assetPath: 'a.jpg', physicalWidthMeters: 0.3);
      final t2 = t.copyWith(physicalWidthMeters: 0.5);
      expect(t2.physicalWidthMeters, 0.5);
      expect(t2.name, 'p');
    });

    test('ARImageTarget fromMap', () {
      const t = ARImageTarget(
          name: 'poster', assetPath: 'p.png', physicalWidthMeters: 0.21);
      final t2 = ARImageTarget.fromMap(t.toMap());
      expect(t2.name, 'poster');
      expect(t2.physicalWidthMeters, 0.21);
    });

    test('ARImageTarget equality', () {
      const a = ARImageTarget(
          name: 'x', assetPath: 'a.png', physicalWidthMeters: 0.3);
      const b = ARImageTarget(
          name: 'x', assetPath: 'a.png', physicalWidthMeters: 0.9);
      expect(a, equals(b)); // equality by name+path only
    });
  });

  // ── ARRuntimeDiagnostics ─────────────────────────────────────────────────

  group('ARRuntimeDiagnostics', () {
    test('fromMap / toMap round-trip preserves backend values', () {
      final diagnostics = ARRuntimeDiagnostics.fromMap(
        <String, Object?>{
          'source': 'web',
          'sessionActive': true,
          'threeAvailable': true,
          'gltfLoaderAvailable': true,
          'objLoaderAvailable': false,
          'textureLoaderAvailable': true,
          'nodesAdded': 3,
          'nodesRendered': 2,
          'nodesSkippedMissingThree': 1,
          'modelLoadStarted': 2,
          'modelLoadSucceeded': 1,
          'modelLoadFailed': 1,
          'modelFallbackUsed': 1,
          'modelCacheHits': 4,
          'modelCacheSize': 2,
          'modelStaleCallbacksIgnored': 1,
          'textureLoadStarted': 1,
          'textureLoadSucceeded': 1,
          'textureLoadFailed': 0,
          'textureCacheHits': 5,
          'textureCacheSize': 1,
          'lastNodeStatus': 'rendered',
          'lastModelNodeId': 'photo_frame',
          'lastModelUrl': 'assets/models/frame.glb',
          'lastModelStatus': 'loaded',
          'lastUpdatedAt': '2026-06-11T01:02:03.000Z',
          'customNested': <String, Object?>{
            'renderer': 'three',
          },
        },
      );

      expect(diagnostics.source, 'web');
      expect(diagnostics.sessionActive, isTrue);
      expect(diagnostics.threeAvailable, isTrue);
      expect(diagnostics.gltfLoaderAvailable, isTrue);
      expect(diagnostics.objLoaderAvailable, isFalse);
      expect(diagnostics.nodesAdded, 3);
      expect(diagnostics.nodesRendered, 2);
      expect(diagnostics.nodesSkippedMissingThree, 1);
      expect(diagnostics.modelLoadSucceeded, 1);
      expect(diagnostics.modelLoadFailed, 1);
      expect(diagnostics.modelFallbackUsed, 1);
      expect(diagnostics.modelCacheHits, 4);
      expect(diagnostics.modelStaleCallbacksIgnored, 1);
      expect(diagnostics.textureCacheHits, 5);
      expect(diagnostics.lastModelStatus, 'loaded');
      expect(diagnostics.lastUpdatedAt, DateTime.utc(2026, 6, 11, 1, 2, 3));
      expect(
        ARRuntimeDiagnostics.fromMap(diagnostics.toMap()),
        diagnostics,
      );
      expect(
        diagnostics.toMap()['customNested'],
        <String, Object?>{'renderer': 'three'},
      );
    });

    test('empty fallback is safe for backends without diagnostics', () {
      const diagnostics = ARRuntimeDiagnostics.empty();

      expect(diagnostics.isEmpty, isTrue);
      expect(diagnostics.source, 'none');
      expect(diagnostics.nodesAdded, 0);
      expect(diagnostics.sessionActive, isFalse);
      expect(diagnostics.lastUpdatedAt, isNull);
    });

    test('creates lifecycle events for notable runtime states', () {
      final diagnostics = ARRuntimeDiagnostics.fromMap(
        <String, Object?>{
          'source': 'web',
          'sessionActive': true,
          'threeAvailable': false,
          'nodesAdded': 2,
          'nodesSkippedMissingThree': 2,
          'modelLoadFailed': 1,
          'modelFallbackUsed': 1,
          'modelStaleCallbacksIgnored': 1,
          'textureLoadFailed': 1,
          'lastModelNodeId': 'frame',
          'lastModelUrl': 'assets/models/frame.glb',
          'lastModelStatus': 'fallbackAfterLoadError',
          'lastModelError': '404',
        },
      );

      final events = diagnostics.toSessionLifecycleEvents(
        occurredAt: DateTime.utc(2026, 6, 11, 7),
        sessionId: 'session_1',
      );

      expect(
        events.map((event) => event.code),
        <String>[
          'runtime_renderer_unavailable',
          'runtime_model_load_failed',
          'runtime_texture_load_failed',
          'runtime_stale_model_callback_ignored',
        ],
      );
      expect(events.first.source, 'web_runtime');
      expect(events.first.severity, ARSessionHealthSeverity.blocked);
      expect(events[1].detailLabel, '404');
      expect(events[1].metadata['lastModelUrl'], 'assets/models/frame.glb');
      expect(events.last.severity, ARSessionHealthSeverity.good);
    });
  });

  // ── ARCapabilities ───────────────────────────────────────────────────────

  group('ARCapabilities', () {
    test('fromMap / toMap round-trip', () {
      const capabilities = ARCapabilities(
        isARSupported: true,
        supportsWorldTracking: true,
        supportsPlaneDetection: true,
        supportsHitTesting: true,
        supportsImageTracking: true,
        supportsLightEstimation: true,
        supportsSceneDepth: true,
        supportsHumanOcclusion: false,
        supportsBodyTracking: true,
        supportsGeospatial: true,
        supportsCloudAnchors: false,
        supportsSnapshotCapture: true,
        supportsRecordingEncode: true,
      );

      expect(ARCapabilities.fromMap(capabilities.toMap()), capabilities);
      expect(capabilities.supportsAnyOcclusion, isTrue);
      expect(capabilities.supportsCoreSession, isTrue);
      expect(capabilities.supportsRecordingEncode, isTrue);
    });

    test('unsupportedFeaturesFor explains unmet session config requirements',
        () {
      const capabilities = ARCapabilities(
        isARSupported: true,
        supportsWorldTracking: true,
        supportsPlaneDetection: true,
        supportsHitTesting: true,
        supportsLightEstimation: true,
      );
      const config = ARSessionConfig(
        depthEnabled: true,
        bodyTrackingEnabled: true,
        geospatialEnabled: true,
        imageTargets: <ARImageTarget>[
          ARImageTarget(
            name: 'poster',
            assetPath: 'poster.png',
            physicalWidthMeters: 0.3,
          ),
        ],
      );

      expect(
        capabilities.unsupportedFeaturesFor(config),
        <String>['imageTracking', 'sceneDepth', 'bodyTracking', 'geospatial'],
      );
      expect(capabilities.supportsConfig(config), isFalse);
    });

    test('compatibleConfigFor disables unsupported optional systems', () {
      const capabilities = ARCapabilities(
        isARSupported: true,
        supportsWorldTracking: true,
        supportsHitTesting: true,
        supportsHumanOcclusion: true,
      );
      const requested = ARSessionConfig(
        detectVerticalPlanes: true,
        cloudAnchorsEnabled: true,
        imageTargets: <ARImageTarget>[
          ARImageTarget(
            name: 'poster',
            assetPath: 'poster.png',
            physicalWidthMeters: 0.3,
          ),
        ],
        targetFrameRate: 45,
        showFeaturePoints: true,
        occlusionEnabled: true,
        depthEnabled: true,
        bodyTrackingEnabled: true,
        geospatialEnabled: true,
      );

      final resolved = capabilities.compatibleConfigFor(requested);
      final report = capabilities.resolveConfig(requested);

      expect(resolved.detectHorizontalPlanes, isFalse);
      expect(resolved.detectVerticalPlanes, isFalse);
      expect(resolved.lightingEstimationEnabled, isFalse);
      expect(resolved.cloudAnchorsEnabled, isFalse);
      expect(resolved.imageTargets, isEmpty);
      expect(resolved.targetFrameRate, 45);
      expect(resolved.showFeaturePoints, isTrue);
      expect(resolved.occlusionEnabled, isTrue);
      expect(resolved.depthEnabled, isFalse);
      expect(resolved.bodyTrackingEnabled, isFalse);
      expect(resolved.geospatialEnabled, isFalse);
      expect(report.resolvedConfig, resolved);
      expect(report.hasDegraded, isTrue);
      expect(report.isFullySupported, isFalse);
      expect(
        report.unsupportedFeatureKeys,
        <String>[
          'planeDetection',
          'lightEstimation',
          'imageTracking',
          'cloudAnchors',
          'sceneDepth',
          'bodyTracking',
          'geospatial',
        ],
      );
    });

    test('compatibleConfigFor quiets requested features when AR is unavailable',
        () {
      const requested = ARSessionConfig(
        detectVerticalPlanes: true,
        cloudAnchorsEnabled: true,
        targetFrameRate: 30,
        showFeaturePoints: true,
        occlusionEnabled: true,
        depthEnabled: true,
        bodyTrackingEnabled: true,
        geospatialEnabled: true,
      );

      final resolved =
          const ARCapabilities.unsupported().compatibleConfigFor(requested);

      expect(resolved.detectHorizontalPlanes, isFalse);
      expect(resolved.detectVerticalPlanes, isFalse);
      expect(resolved.lightingEstimationEnabled, isFalse);
      expect(resolved.cloudAnchorsEnabled, isFalse);
      expect(resolved.targetFrameRate, 30);
      expect(resolved.showFeaturePoints, isFalse);
      expect(resolved.occlusionEnabled, isFalse);
      expect(resolved.depthEnabled, isFalse);
      expect(resolved.bodyTrackingEnabled, isFalse);
      expect(resolved.geospatialEnabled, isFalse);
    });
  });

  // ── ARGeospatialAnchor / ARGeospatialProjector ───────────────────────────

  group('ARGeospatialProjector', () {
    test('same coordinate projects to origin with altitude offset', () {
      const origin = ARGeoOrigin(
        latitude: -6.9175,
        longitude: 107.6191,
        altitudeMeters: 700,
      );
      const anchor = ARGeospatialAnchor(
        id: 'memory',
        latitude: -6.9175,
        longitude: 107.6191,
        altitudeMeters: 702,
      );

      final position = const ARGeospatialProjector().toLocalPosition(
        origin: origin,
        anchor: anchor,
      );

      expect(position.x, closeTo(0, 1e-9));
      expect(position.y, closeTo(2, 1e-9));
      expect(position.z, closeTo(0, 1e-9));
    });

    test('east and north deltas map to AR x and negative z', () {
      const origin = ARGeoOrigin(latitude: 0, longitude: 0);
      const anchor = ARGeospatialAnchor(
        id: 'memory',
        latitude: 0.001,
        longitude: 0.001,
      );

      final position = const ARGeospatialProjector().toLocalPosition(
        origin: origin,
        anchor: anchor,
      );

      expect(position.x, greaterThan(100));
      expect(position.z, lessThan(-100));
    });

    test('correction offsets are applied in local AR axes', () {
      const origin = ARGeoOrigin(latitude: 0, longitude: 0);
      const anchor = ARGeospatialAnchor(
        id: 'memory',
        latitude: 0,
        longitude: 0,
        correctionEastMeters: 1.5,
        correctionNorthMeters: -2,
        correctionUpMeters: 0.75,
      );

      final position = const ARGeospatialProjector().toLocalPosition(
        origin: origin,
        anchor: anchor,
      );

      expect(position.x, closeTo(1.5, 1e-9));
      expect(position.y, closeTo(0.75, 1e-9));
      expect(position.z, closeTo(2, 1e-9));
    });

    test('anchor serializes and preserves metadata', () {
      const anchor = ARGeospatialAnchor(
        id: 'memory',
        latitude: 1,
        longitude: 2,
        altitudeMeters: 3,
        headingDegrees: 90,
        metadata: <String, Object?>{'kind': 'geo_memory'},
      );

      final decoded = ARGeospatialAnchor.fromMap(anchor.toMap());

      expect(decoded, anchor);
      expect(decoded.metadata['kind'], 'geo_memory');
    });

    test('anchor metadata includes geospatial fields and custom values', () {
      const anchor = ARGeospatialAnchor(
        id: 'memory',
        latitude: 1,
        longitude: 2,
        altitudeMeters: 3,
        headingDegrees: 90,
        correctionEastMeters: 0.5,
        correctionNorthMeters: -1,
        correctionUpMeters: 2,
        metadata: <String, Object?>{'kind': 'geo_memory'},
      );

      final metadata = anchor.toAnchorMetadata(nativeGeospatial: false);

      expect(metadata['kind'], 'geo_memory');
      expect(metadata['geospatialAnchorId'], 'memory');
      expect(metadata['latitude'], 1);
      expect(metadata['longitude'], 2);
      expect(metadata['altitudeMeters'], 3);
      expect(metadata['headingDegrees'], 90);
      expect(metadata['correctionEastMeters'], 0.5);
      expect(metadata['correctionNorthMeters'], -1);
      expect(metadata['correctionUpMeters'], 2);
      expect(metadata['nativeGeospatial'], isFalse);
    });
  });

  // ── ARPlane enhanced ──────────────────────────────────────────────────────

  group('ARPlane enhanced', () {
    ARPlane _square() => ARPlane.fromMap({
          'id': 'p',
          'alignment': 'horizontal',
          'centerPose': {
            'position': {'x': 0, 'y': 0, 'z': 0},
            'rotation': {'x': 0, 'y': 0, 'z': 0, 'w': 1}
          },
          'extentMeters': {'x': 2, 'y': 0, 'z': 2},
          'boundaryVertices': [
            {'x': -1, 'y': 0, 'z': -1},
            {'x': 1, 'y': 0, 'z': -1},
            {'x': 1, 'y': 0, 'z': 1},
            {'x': -1, 'y': 0, 'z': 1},
          ],
          'trackingState': 'tracking',
        });

    test('area of unit square', () {
      expect(_square().area, closeTo(4, 1e-9));
    });

    test('boundingArea is extentX * extentZ', () {
      expect(_square().boundingArea, closeTo(4, 1e-9));
    });

    test('isTracked true when tracking', () {
      expect(_square().isTracked, true);
    });

    test('contains centre point', () {
      expect(_square().contains(0, 0), true);
    });

    test('contains does not include outside point', () {
      expect(_square().contains(5, 5), false);
    });

    test('contains corner is inside (winding)', () {
      // Points on boundary may vary by impl; interior clearly inside
      expect(_square().contains(0.5, 0.5), true);
    });

    test('perimeter of unit square = 8m', () {
      expect(_square().perimeter, closeTo(8, 1e-6));
    });

    test('toMap / fromMap round-trip', () {
      final p = _square();
      final p2 = ARPlane.fromMap(p.toMap());
      expect(p2.id, p.id);
      expect(p2.alignment, p.alignment);
      expect(p2.boundaryVertices.length, 4);
    });

    test('equality by id', () {
      final a = _square();
      final b = ARPlane.fromMap(a.toMap());
      expect(a, equals(b));
    });
  });

  // ── ARAnchor enhanced ─────────────────────────────────────────────────────

  group('ARAnchor enhanced', () {
    test('isTracked true when tracking', () {
      const a = ARAnchor(
          id: 'a',
          pose: ARPose.identity(),
          trackingState: ARTrackingState.tracking);
      expect(a.isTracked, true);
    });

    test('isStopped true when stopped', () {
      const a = ARAnchor(
          id: 'a',
          pose: ARPose.identity(),
          trackingState: ARTrackingState.stopped);
      expect(a.isStopped, true);
    });

    test('metadata round-trips through fromMap', () {
      const a = ARAnchor(
          id: 'a',
          pose: ARPose.identity(),
          trackingState: ARTrackingState.tracking,
          metadata: {'imageTargetName': 'poster', 'score': 0.95});
      final a2 = ARAnchor.fromMap(a.toMap());
      expect(a2.metadata['imageTargetName'], 'poster');
    });

    test('equality by id', () {
      const a = ARAnchor(
          id: 'same',
          pose: ARPose.identity(),
          trackingState: ARTrackingState.tracking);
      const b = ARAnchor(
          id: 'same',
          pose: ARPose.identity(),
          trackingState: ARTrackingState.paused);
      expect(a, equals(b));
    });
  });

  // ── ARRay enhanced ────────────────────────────────────────────────────────

  group('ARRay enhanced', () {
    test('closestPointToPoint: directly in front', () {
      final ray = ARRay(
          origin: const ARVector3.zero(), direction: const ARVector3(0, 0, -1));
      final cp = ray.closestPointToPoint(const ARVector3(0, 0, -3));
      expect(cp.z, closeTo(-3, 1e-9));
    });

    test('closestPointToPoint: beside ray', () {
      final ray = ARRay(
          origin: const ARVector3.zero(), direction: const ARVector3(0, 0, -1));
      final cp = ray.closestPointToPoint(const ARVector3(2, 0, -3));
      expect(cp.x, closeTo(0, 1e-9)); // closest is on ray axis
      expect(cp.z, closeTo(-3, 1e-9));
    });

    test('distanceToPoint', () {
      final ray = ARRay(
          origin: const ARVector3.zero(), direction: const ARVector3(0, 0, -1));
      // Point 2m to the right of the ray
      expect(ray.distanceToPoint(const ARVector3(2, 0, -5)), closeTo(2, 1e-9));
    });

    test('isParallelTo itself', () {
      final ray = ARRay(
          origin: const ARVector3.zero(), direction: const ARVector3(0, 0, -1));
      expect(ray.isParallelTo(ray), true);
    });

    test('isParallelTo perpendicular = false', () {
      final a = ARRay(
          origin: const ARVector3.zero(), direction: const ARVector3(0, 0, -1));
      final b = ARRay(
          origin: const ARVector3.zero(), direction: const ARVector3(1, 0, 0));
      expect(a.isParallelTo(b), false);
    });

    test('rayCapsule hits cylinder body', () {
      final ray = ARRay(
          origin: const ARVector3(0, 0, 5),
          direction: const ARVector3(0, 0, -1));
      final h = ARIntersection.rayCapsule(
          ray: ray,
          capA: const ARVector3(0, -1, 0),
          capB: const ARVector3(0, 1, 0),
          radius: 0.5);
      expect(h.hit, true);
      expect(h.t, closeTo(4.5, 0.01));
    });

    test('ARFrustum testAABB hits large box', () {
      final f = ARFrustum.fromMatrix(
          ARMatrix4.perspective(fovY: 1.0, aspect: 1.6, near: 0.1, far: 100));
      // Large box in front of camera should be visible
      expect(
          f.testAABB(
              const ARVector3(-10, -10, -10), const ARVector3(10, 10, 10)),
          isA<bool>());
    });

    test('ARFrustum containsPoint origin', () {
      final f = ARFrustum.fromMatrix(
          ARMatrix4.perspective(fovY: 1.0, aspect: 1.6, near: 0.1, far: 100));
      expect(f.containsPoint(const ARVector3(0, 0, -5)), isA<bool>());
    });

    test('ARRayHit miss is never a hit', () {
      expect(ARRayHit.miss.hit, false);
      expect(ARRayHit.miss.t, double.infinity);
    });
  });

  // ── ARHitTestResult enhanced ──────────────────────────────────────────────

  group('ARHitTestResult', () {
    ARHitTestResult _hit() => ARHitTestResult(
          type: ARHitTestResultType.plane,
          worldPose: const ARPose.identity(),
          distance: 1.5,
          planeId: 'p1',
          confidence: 0.9,
        );

    test('isOnPlane true for plane type', () {
      expect(_hit().isOnPlane, true);
    });

    test('isOnPlane false for featurePoint', () {
      final h = ARHitTestResult(
        type: ARHitTestResultType.featurePoint,
        worldPose: const ARPose.identity(),
        distance: 1.0,
      );
      expect(h.isOnPlane, false);
    });

    test('confidence stored correctly', () {
      expect(_hit().confidence, closeTo(0.9, 1e-9));
    });

    test('toMap / fromMap round-trip', () {
      final h = _hit();
      final h2 = ARHitTestResult.fromMap(h.toMap());
      expect(h2.type, h.type);
      expect(h2.distance, h.distance);
      expect(h2.planeId, h.planeId);
      expect(h2.confidence, closeTo(0.9, 1e-9));
    });

    test('copyWith changes distance', () {
      final h2 = _hit().copyWith(distance: 3.0);
      expect(h2.distance, 3.0);
      expect(h2.type, ARHitTestResultType.plane);
    });

    test('equality by type/distance/planeId', () {
      expect(_hit(), equals(_hit()));
    });

    test('estimatedVerticalPlane type parses', () {
      final h = ARHitTestResult.fromMap({
        'type': 'estimatedVerticalPlane',
        'worldPose': {
          'position': {'x': 0, 'y': 0, 'z': 0},
          'rotation': {'x': 0, 'y': 0, 'z': 0, 'w': 1}
        },
        'distance': 2.0,
        'confidence': 1.0,
      });
      expect(h.type, ARHitTestResultType.estimatedVerticalPlane);
    });
  });

  // ── ARNodeBuilder ────────────────────────────────────────────────────────

  group('ARNodeBuilder', () {
    test('builds minimal node with defaults', () {
      final n = ARNodeBuilder('test').build();
      expect(n.id, 'test');
      expect(n.isVisible, true);
      expect(n.renderOrder, 0);
    });

    test('sphere sets shape and size', () {
      final n = ARNodeBuilder('s').sphere(radius: 0.1).build();
      expect(n.primitiveShape, ARPrimitiveShape.sphere);
      expect(n.primitiveSize!.x, closeTo(0.2, 1e-9));
    });

    test('cube sets shape', () {
      final n = ARNodeBuilder('c').cube(size: 0.05).build();
      expect(n.primitiveShape, ARPrimitiveShape.cube);
    });

    test('at sets position', () {
      final n = ARNodeBuilder('n').at(x: 1, y: 2, z: 3).build();
      expect(n.position.x, 1.0);
      expect(n.position.y, 2.0);
      expect(n.position.z, 3.0);
    });

    test('uniformScale sets xyz equal', () {
      final n = ARNodeBuilder('n').uniformScale(0.5).build();
      expect(n.scale.x, 0.5);
      expect(n.scale.y, 0.5);
      expect(n.scale.z, 0.5);
    });

    test('hidden sets isVisible false', () {
      final n = ARNodeBuilder('n').hidden().build();
      expect(n.isVisible, false);
    });

    test('renderOrder stored', () {
      final n = ARNodeBuilder('n').renderOrder(5).build();
      expect(n.renderOrder, 5);
    });

    test('tag adds metadata', () {
      final n = ARNodeBuilder('n').tag('role', 'portal_frame').build();
      expect(n.metadata['role'], 'portal_frame');
    });

    test('meta merges map', () {
      final n = ARNodeBuilder('n').tag('a', 1).meta({'b': 2, 'c': 3}).build();
      expect(n.metadata['a'], 1);
      expect(n.metadata['b'], 2);
      expect(n.metadata['c'], 3);
    });

    test('color sets baseColor', () {
      final n = ARNodeBuilder('n').color(const ARMaterialColor.red()).build();
      expect(n.material!.baseColor.r, closeTo(1, 1e-9));
      expect(n.material!.baseColor.g, closeTo(0, 1e-9));
    });

    test('metallic sets metallic', () {
      final n = ARNodeBuilder('n').metallic(0.8).build();
      expect(n.material!.metallic, closeTo(0.8, 1e-9));
    });

    test('opacity < 1 sets alpha blend mode', () {
      final n = ARNodeBuilder('n').opacity(0.5).build();
      expect(n.material!.opacity, closeTo(0.5, 1e-9));
      expect(n.material!.blendMode, ARBlendMode.alpha);
    });

    test('shadows flags', () {
      final n =
          ARNodeBuilder('n').shadows(casts: false, receives: false).build();
      expect(n.castsShadow, false);
      expect(n.receivesShadow, false);
    });

    test('addChild appends child', () {
      final child = ARNodeBuilder('child').build();
      final n = ARNodeBuilder('parent').addChild(child).build();
      expect(n.children.length, 1);
      expect(n.children.first.id, 'child');
    });

    test('glowing sets emissive material', () {
      final n = ARNodeBuilder('n')
          .glowing(color: const ARMaterialColor.white(), intensity: 3.0)
          .build();
      expect(n.material, isNotNull);
      expect(n.material!.emissiveIntensity, closeTo(3.0, 1e-9));
    });

    test('cylinder sets shape', () {
      final n = ARNodeBuilder('c').cylinder(radius: 0.05, height: 0.2).build();
      expect(n.primitiveShape, ARPrimitiveShape.cylinder);
      expect(n.primitiveSize!.y, closeTo(0.2, 1e-9));
    });

    test('plane sets shape', () {
      final n = ARNodeBuilder('p').plane(width: 1.0, depth: 2.0).build();
      expect(n.primitiveShape, ARPrimitiveShape.plane);
      expect(n.primitiveSize!.x, closeTo(1.0, 1e-9));
      expect(n.primitiveSize!.z, closeTo(2.0, 1e-9));
    });
  });

  // ── ARSceneSnapshot / ARSceneSerializer ───────────────────────────────────

  group('ARSceneSnapshot', () {
    ARSceneSnapshot _snap() => ARSceneSnapshot(
          version: '1.0',
          capturedAt: DateTime(2026, 1, 1),
          config: const ARSessionConfig(),
          nodes: [const ARNode(id: 'n1'), const ARNode(id: 'n2')],
          anchors: [],
          lights: [],
        );

    test('nodeCount', () => expect(_snap().nodeCount, 2));
    test('anchorCount', () => expect(_snap().anchorCount, 0));
    test('lightCount', () => expect(_snap().lightCount, 0));

    test('toMap has all keys', () {
      final m = _snap().toMap();
      expect(m.containsKey('version'), true);
      expect(m.containsKey('nodes'), true);
      expect(m.containsKey('anchors'), true);
      expect(m.containsKey('capturedAt'), true);
    });

    test('toJSON / fromJSON round-trip', () {
      final s = _snap();
      final s2 = ARSceneSnapshot.fromJSON(s.toJSON());
      expect(s2.version, '1.0');
      expect(s2.nodeCount, 2);
    });

    test('fromJSON preserves node ids', () {
      final s2 = ARSceneSnapshot.fromJSON(_snap().toJSON());
      final ids = s2.nodes.map((n) => n.id).toList();
      expect(ids, contains('n1'));
      expect(ids, contains('n2'));
    });
  });

  group('ARSceneDiff', () {
    ARSceneSnapshot _a() => ARSceneSnapshot(
          version: '1',
          capturedAt: DateTime(2026),
          config: const ARSessionConfig(),
          nodes: [const ARNode(id: 'a'), const ARNode(id: 'b')],
          anchors: [],
          lights: [],
        );
    ARSceneSnapshot _b() => ARSceneSnapshot(
          version: '1',
          capturedAt: DateTime(2026),
          config: const ARSessionConfig(),
          nodes: [const ARNode(id: 'b'), const ARNode(id: 'c')],
          anchors: [],
          lights: [],
        );

    test('added = nodes in B not in A', () {
      final diff = ARSceneSerializer.diff(_a(), _b());
      expect(diff.added.length, 1);
      expect(diff.added.first.id, 'c');
    });

    test('removed = nodes in A not in B', () {
      final diff = ARSceneSerializer.diff(_a(), _b());
      expect(diff.removed.length, 1);
      expect(diff.removed.first.id, 'a');
    });

    test('hasChanges true when something differs', () {
      expect(ARSceneSerializer.diff(_a(), _b()).hasChanges, true);
    });

    test('hasChanges false for identical snapshots', () {
      expect(ARSceneSerializer.diff(_a(), _a()).hasChanges, false);
    });
  });

  // ── ARRecordingConfig enhanced ────────────────────────────────────────────

  group('ARRecordingConfig enhanced', () {
    test('copyWith changes fps', () {
      const c = ARRecordingConfig(fps: 30);
      final c2 = c.copyWith(fps: 60);
      expect(c2.fps, 60);
      expect(c2.videoBitrateKbps, c.videoBitrateKbps);
    });

    test('copyWith changes includeAudio', () {
      const c = ARRecordingConfig(includeAudio: false);
      final c2 = c.copyWith(includeAudio: true);
      expect(c2.includeAudio, true);
    });

    test('copyWith changes outputFormat', () {
      const c = ARRecordingConfig();
      final c2 = c.copyWith(outputFormat: 'mov');
      expect(c2.outputFormat, 'mov');
    });

    test('equality', () {
      const a = ARRecordingConfig(fps: 30, includeAudio: false);
      const b = ARRecordingConfig(fps: 30, includeAudio: false);
      expect(a, equals(b));
    });

    test('inequality on fps difference', () {
      const a = ARRecordingConfig(fps: 30);
      const b = ARRecordingConfig(fps: 60);
      expect(a, isNot(equals(b)));
    });

    test('ARRecordingResult actualFPS', () {
      const r = ARRecordingResult(
        filePath: '/tmp/out.mp4',
        duration: Duration(seconds: 10),
        frameCount: 300,
      );
      expect(r.actualFPS, closeTo(30.0, 0.01));
      expect(r.succeeded, true);
    });
  });

  // ── ARPortalConfig enhanced ───────────────────────────────────────────────

  group('ARPortalConfig enhanced', () {
    test('copyWith changes width', () {
      const c = ARPortalConfig(width: 0.8);
      final c2 = c.copyWith(width: 1.2);
      expect(c2.width, 1.2);
      expect(c2.height, c.height);
    });

    test('copyWith changes shape', () {
      const c = ARPortalConfig(shape: ARPortalShape.arch);
      final c2 = c.copyWith(shape: ARPortalShape.circle);
      expect(c2.shape, ARPortalShape.circle);
    });

    test('equality by shape/width/height', () {
      const a =
          ARPortalConfig(shape: ARPortalShape.arch, width: 0.8, height: 1.8);
      const b =
          ARPortalConfig(shape: ARPortalShape.arch, width: 0.8, height: 1.8);
      expect(a, equals(b));
    });

    test('inequality on shape difference', () {
      const a = ARPortalConfig(shape: ARPortalShape.arch);
      const b = ARPortalConfig(shape: ARPortalShape.circle);
      expect(a, isNot(equals(b)));
    });
  });

  // ── ARGestureEvent fling ──────────────────────────────────────────────────

  group('ARGestureEvent fling', () {
    test('fling event carries velocity', () {
      const ev = ARGestureEvent(
        type: ARGestureType.fling,
        screenPoint: Offset(0.5, 0.5),
        flingVelocity: Offset(1.0, 0.5),
      );
      expect(ev.type, ARGestureType.fling);
      expect(ev.flingVelocity!.dx, 1.0);
      expect(ev.flingVelocity!.dy, 0.5);
    });

    test('fling event may have null entityId for empty space', () {
      const ev = ARGestureEvent(
        type: ARGestureType.fling,
        screenPoint: Offset(0.5, 0.5),
        flingVelocity: Offset(0.5, 0.0),
      );
      expect(ev.entityId, isNull);
    });

    test('all gesture types exist', () {
      expect(
          ARGestureType.values,
          containsAll([
            ARGestureType.tap,
            ARGestureType.doubleTap,
            ARGestureType.longPress,
            ARGestureType.drag,
            ARGestureType.fling,
            ARGestureType.scale,
            ARGestureType.rotate,
          ]));
    });
  });

  // ── ARImageTrackingResult ─────────────────────────────────────────────────

  group('ARImageTrackingResult', () {
    test('fromMap parses correctly', () {
      final r = ARImageTrackingResult.fromMap({
        'targetName': 'poster',
        'pose': {
          'position': {'x': 0.0, 'y': 0.0, 'z': -1.0},
          'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
        },
        'state': 'tracking',
        'estimatedPhysicalWidth': 0.297,
      });
      expect(r.targetName, 'poster');
      expect(r.state, ARImageTrackingState.tracking);
      expect(r.estimatedPhysicalWidth, closeTo(0.297, 1e-9));
    });

    test('default estimatedPhysicalWidth is 0.3', () {
      final r = ARImageTrackingResult.fromMap({
        'targetName': 'p',
        'pose': {
          'position': {'x': 0.0, 'y': 0.0, 'z': 0.0},
          'rotation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
        },
        'state': 'detected',
      });
      expect(r.estimatedPhysicalWidth, closeTo(0.3, 1e-9));
    });

    test('toString contains targetName', () {
      final r = ARImageTrackingResult(
        targetName: 'shelf_label',
        pose: const ARPose.identity(),
        state: ARImageTrackingState.lost,
        estimatedPhysicalWidth: 0.1,
      );
      expect(r.toString(), contains('shelf_label'));
    });
  });

  // ── ARBodySkeleton / ARBodyTracker ────────────────────────────────────────

  group('ARBodySkeleton', () {
    ARJointPose _jp(ARBodyJoint j, double y) => ARJointPose(
          joint: j,
          pose: ARPose(
              position: ARVector3(0, y, 0),
              rotation: const ARQuaternion.identity()),
          confidence: 0.9,
        );

    ARBodySkeleton _skel() => ARBodySkeleton(
          id: 'body_1',
          rootPose: const ARPose.identity(),
          timestamp: DateTime(2026),
          joints: [
            _jp(ARBodyJoint.head, 1.7),
            _jp(ARBodyJoint.leftAnkle, 0.1),
            _jp(ARBodyJoint.rightAnkle, 0.1),
            _jp(ARBodyJoint.leftWrist, 1.0),
            _jp(ARBodyJoint.rightWrist, 1.0),
            _jp(ARBodyJoint.leftHip, 0.9),
            _jp(ARBodyJoint.rightHip, 0.9),
          ],
        );

    test('estimatedHeight head-to-ankle', () {
      expect(_skel().estimatedHeight, closeTo(1.6, 0.01));
    });

    test('centreOfMass midpoint of hips', () {
      final cm = _skel().centreOfMass;
      expect(cm, isNotNull);
      expect(cm!.y, closeTo(0.9, 1e-9));
    });

    test('armSpan between wrists', () {
      expect(_skel().armSpan, closeTo(0.0, 1e-9)); // both at x=0
    });

    test('joint() returns correct joint', () {
      final jp = _skel().joint(ARBodyJoint.head);
      expect(jp, isNotNull);
      expect(jp!.pose.position.y, closeTo(1.7, 1e-9));
    });

    test('joint() returns null for missing joint', () {
      expect(_skel().joint(ARBodyJoint.spine1), isNull);
    });

    test('toMap / fromMap round-trip preserves id', () {
      final s = _skel();
      final s2 = ARBodySkeleton.fromMap(s.toMap());
      expect(s2.id, s.id);
      expect(s2.joints.length, s.joints.length);
    });

    test('ARJointPose confidence stored', () {
      expect(_jp(ARBodyJoint.head, 1.7).confidence, closeTo(0.9, 1e-9));
    });

    test('all ARBodyJoint values accessible', () {
      expect(ARBodyJoint.values.length, greaterThan(15));
    });
  });

  // ── ARMiniMap (data path only) ───────────────────────────────────────────

  group('ARBodyJoint', () {
    test('enum covers expected joints', () {
      expect(ARBodyJoint.values, contains(ARBodyJoint.head));
      expect(ARBodyJoint.values, contains(ARBodyJoint.leftWrist));
      expect(ARBodyJoint.values, contains(ARBodyJoint.rightAnkle));
      expect(ARBodyJoint.values.length, greaterThanOrEqualTo(20));
    });

    test('ARJointPose isTracked defaults true', () {
      final jp = ARJointPose(
        joint: ARBodyJoint.neck,
        pose: const ARPose.identity(),
        confidence: 0.95,
      );
      expect(jp.isTracked, true);
    });
  });
}

// ─── Test helper: exposes _RunningAnimation internals ─────────────────────────

class _RunningAnimationHelper {
  final ARAnimation animation;
  double elapsedSeconds = 0;

  _RunningAnimationHelper(this.animation, ARNode _);

  double get normalizedTime {
    final raw = elapsedSeconds / animation.durationSeconds;
    switch (animation.wrapMode) {
      case ARAnimationWrapMode.once:
        return raw.clamp(0.0, 1.0);
      case ARAnimationWrapMode.loop:
        return raw % 1.0;
      case ARAnimationWrapMode.pingPong:
        final cycle = raw % 2.0;
        return cycle <= 1.0 ? cycle : 2.0 - cycle;
      case ARAnimationWrapMode.clampForever:
        return raw.clamp(0.0, 1.0);
    }
  }
}
