import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_hosting_service.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

/// Hosts the cloud anchors of the frames currently in the AR scene without
/// ever hosting the same frame twice at once.
///
/// Scene syncs can overlap (a retry, a maintenance wake-up and a pose change
/// can all ask for a sync), and hosting is slow and billable, so a frame whose
/// hosting is still running is skipped by the next call. Hosting is
/// opportunistic: a native error never throws, it comes back as a failed
/// result so the caller can schedule a retry and placement keeps working.
class CloudAnchorHostCoordinator {
  final Set<String> _inFlight = <String>{};

  /// Frames whose hosting is running right now.
  Set<String> get inFlightMemoryIds => Set<String>.unmodifiable(_inFlight);

  /// Forgets what is in flight, for when the AR session ends and those calls
  /// can no longer finish usefully.
  void clear() => _inFlight.clear();

  /// Hosts the frames in [active] that are not already being hosted.
  ///
  /// [hostCall] does the real hosting for the frames it is given.
  /// [onRecords] is told about the anchors that were hosted, before the
  /// result is returned; an error there is treated like a hosting error.
  Future<ARMemoryCloudAnchorHostingResult> host({
    required List<JejakuPlacedMemory> active,
    required Future<ARMemoryCloudAnchorHostingResult> Function(
      List<JejakuPlacedMemory> hostable,
    ) hostCall,
    required void Function(List<JejakuMemoryCloudAnchor> records) onRecords,
  }) async {
    final hostable = [
      for (final placed in active)
        if (!_inFlight.contains(placed.memory.id)) placed,
    ];
    if (hostable.isEmpty) {
      return const ARMemoryCloudAnchorHostingResult();
    }

    final ids = {for (final placed in hostable) placed.memory.id};
    _inFlight.addAll(ids);
    try {
      final result = await hostCall(hostable);
      if (result.records.isNotEmpty) {
        onRecords(result.records);
      }
      return result;
    } catch (_) {
      // Native cloud persistence is opportunistic; placement still works.
      return ARMemoryCloudAnchorHostingResult(
        failedMemoryIds: ids,
        failureReasons: <String, ARMemoryCloudAnchorHostingFailureReason>{
          for (final id in ids)
            id: ARMemoryCloudAnchorHostingFailureReason.nativeError,
        },
      );
    } finally {
      _inFlight.removeAll(ids);
    }
  }
}
