import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/models/anchor_media_sync_manifest.dart';

void main() {
  test('manifest describes stored byte payloads without local paths', () {
    final manifest = AnchorMediaSyncManifest.fromAttachment(
      AnchorMediaAttachment(
        mediaId: 'media_arSnapshot_0001',
        storagePath: 'jejaku://media/media_arSnapshot_0001',
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
      uploadEntry: const AnchorMediaUploadEntry(
        key: 'media_arSnapshot_0001',
        memoryId: 'anchor_snapshot',
        mediaId: 'media_arSnapshot_0001',
        status: AnchorMediaUploadStatus.uploaded,
        retryCount: 1,
      ),
    );

    expect(manifest.statusLabel, 'Stored media');
    expect(manifest.identityLabel, 'media_arSnapshot_0001');
    expect(manifest.storageLabel, 'jejaku://media/media_arSnapshot_0001');
    expect(manifest.payloadLabel, '3 B payload');
    expect(manifest.uploadStatusLabel, 'Media uploaded');
    expect(manifest.retryLabel, '1 retry');
  });

  test('manifest flags legacy file-backed media as pending storage', () {
    final manifest = AnchorMediaSyncManifest.fromAttachment(
      const AnchorMediaAttachment(
        type: AnchorMediaType.arRecording,
        filePath: '/tmp/legacy_clip.mp4',
        duration: Duration(milliseconds: 1200),
        frameCount: 36,
      ),
    );

    expect(manifest.statusLabel, 'Storage pending');
    expect(manifest.identityLabel, 'Unstored media');
    expect(manifest.storageLabel, 'Storage pending');
    expect(manifest.payloadLabel, 'File-backed payload');
    expect(
      manifest.summaryLabel,
      'AR screen recording: 1.2 s - 36 frames',
    );
  });

  test('manifest describes bundled 3D model assets as metadata-only', () {
    final manifest = AnchorMediaSyncManifest.fromAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arModel,
        modelAsset: ARModelAsset.fromPath(
          'assets/models/offline_marker.obj',
          package: 'jezaku_models',
        ),
      ),
    );

    expect(manifest.requiresUpload, isFalse);
    expect(manifest.payloadLabel, '3D model metadata');
    expect(manifest.modelFormatLabel, 'OBJ model');
    expect(manifest.modelSourceLabel, 'Flutter asset');
    expect(manifest.modelPathLabel, 'offline_marker.obj');
    expect(manifest.modelPackageLabel, 'Package jezaku_models');
    expect(manifest.modelValidationIsValid, isTrue);
    expect(manifest.modelValidationLabel, 'Model asset ready with 1 warning');
    expect(manifest.modelValidationWarningLabels, [
      'No fallback size supplied; primitive fallback uses the node scale.',
    ]);
    expect(manifest.modelValidationErrorLabels, isEmpty);
    expect(manifest.modelUsesAndroidPrimitiveFallback, isFalse);
    expect(manifest.modelRenderProfileLabel, 'Native mesh on Android and iOS');
    expect(manifest.modelRenderProfileLabels, [
      'Android native OBJ mesh',
      'iOS native SceneKit mesh',
    ]);
    expect(manifest.modelAndroidRenderMode, 'nativeMesh');
    expect(manifest.modelIosRenderMode, 'nativeMesh');
    expect(manifest.modelUsesAnyPrimitiveFallback, isFalse);
    expect(manifest.modelRequiresPreparation, isFalse);
  });

  test('manifest keeps local 3D model files uploadable', () {
    final manifest = AnchorMediaSyncManifest.fromAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arModel,
        modelAsset: ARModelAsset.fromPath(
          '/tmp/imported_marker.glb',
          source: ARModelAssetSource.file,
        ),
      ),
    );

    expect(manifest.requiresUpload, isTrue);
    expect(manifest.payloadLabel, '3D model file payload');
    expect(manifest.modelFormatLabel, 'GLB model');
    expect(manifest.modelSourceLabel, 'Local model file');
    expect(manifest.modelPathLabel, 'imported_marker.glb');
    expect(manifest.modelValidationIsValid, isTrue);
    expect(manifest.modelValidationLabel, 'Model asset ready with 3 warnings');
    expect(
      manifest.modelValidationIssueLabels,
      contains(
        'Android imports OBJ meshes directly; this format uses primitive fallback rendering.',
      ),
    );
    expect(
      manifest.modelValidationIssueLabels,
      contains(
        'iOS SceneKit loading may require conversion for this model format.',
      ),
    );
    expect(manifest.modelUsesAndroidPrimitiveFallback, isTrue);
    expect(
      manifest.modelRenderProfileLabel,
      'Android primitive fallback; iOS model conversion recommended',
    );
    expect(manifest.modelRenderProfileLabels, [
      'Android primitive fallback',
      'iOS model conversion recommended',
    ]);
    expect(
      manifest.modelRenderProfileNotes,
      contains('Convert to OBJ for Android native mesh rendering.'),
    );
    expect(manifest.modelAndroidRenderMode, 'primitiveFallback');
    expect(manifest.modelIosRenderMode, 'requiresPreparation');
    expect(manifest.modelUsesAnyPrimitiveFallback, isTrue);
    expect(manifest.modelRequiresPreparation, isTrue);
  });
}
