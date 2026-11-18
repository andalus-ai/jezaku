import 'package:ar_engine/ar_engine.dart';

/// Health policy the AR viewer uses to decide whether saved memories may be
/// placed in the native scene.
///
/// The viewer only *shows* memories that already have a stored pose. It does
/// not need the stricter conditions that new-anchor *placement* needs (enough
/// light and tracked planes to hit-test a surface). Using
/// [ARSessionHealthPolicy.placementReadiness] here silently blocked every
/// saved frame in a dim room or in front of a blank wall, leaving only the 2D
/// Flutter fallback cards visible.
///
/// Camera, tracking and session-lifecycle problems still block placement;
/// only the low-light and no-tracked-plane warnings are switched off.
/// Capture flows that create new anchors should keep using
/// [ARSessionHealthPolicy.placementReadiness].
abstract final class ARViewerHealthPolicy {
  static const ARSessionHealthPolicy viewing = ARSessionHealthPolicy();
}
