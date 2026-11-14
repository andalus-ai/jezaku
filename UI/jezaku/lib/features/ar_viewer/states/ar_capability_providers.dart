import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

final arViewerLivePoseTrackingProvider = Provider<bool>((ref) => true);

final arViewerCapabilitiesProvider =
    FutureProvider<JejakuARCapabilities>((ref) async {
  try {
    return await JejakuARCapabilities.query();
  } on MissingPluginException {
    return const JejakuARCapabilities(engine: ARCapabilities.unsupported());
  } on Object {
    return const JejakuARCapabilities(engine: ARCapabilities.unsupported());
  }
});

final arViewerSessionPlanProvider =
    FutureProvider<JejakuARSessionPlan>((ref) async {
  final capabilities = await ref.watch(arViewerCapabilitiesProvider.future);
  return capabilities.planSession(
    detectHorizontalPlanes: true,
    detectVerticalPlanes: true,
    lightingEstimationEnabled: true,
    preferNativeGeospatial: true,
    preferCloudAnchors: false,
    preferDepth: false,
    preferOcclusion: false,
  );
});

final arViewerSessionConfigProvider =
    FutureProvider<ARSessionConfig>((ref) async {
  final plan = await ref.watch(arViewerSessionPlanProvider.future);
  return plan.preferredConfig;
});
