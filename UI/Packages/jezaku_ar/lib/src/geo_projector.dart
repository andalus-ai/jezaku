import 'package:ar_engine/ar_engine.dart';

import 'geo_anchor.dart';

class JejakuGeoProjector {
  const JejakuGeoProjector({this.earthRadiusMeters = 6378137});

  final double earthRadiusMeters;

  ARVector3 toLocalPosition({
    required JejakuGeoOrigin origin,
    required JejakuGeoAnchor anchor,
  }) {
    return ARGeospatialProjector(
      earthRadiusMeters: earthRadiusMeters,
    ).toLocalPosition(
      origin: origin.toARGeoOrigin(),
      anchor: anchor.toARGeospatialAnchor(),
    );
  }

  ARQuaternion toLocalRotation(JejakuGeoAnchor anchor) {
    return ARGeospatialProjector(
      earthRadiusMeters: earthRadiusMeters,
    ).toLocalRotation(anchor.toARGeospatialAnchor());
  }

  ARPoseInput toPoseInput({
    required JejakuGeoOrigin origin,
    required JejakuGeoAnchor anchor,
  }) {
    final pose = ARGeospatialProjector(
      earthRadiusMeters: earthRadiusMeters,
    ).toLocalPose(
      origin: origin.toARGeoOrigin(),
      anchor: anchor.toARGeospatialAnchor(),
    );

    return ARPoseInput(
      x: pose.position.x,
      y: pose.position.y,
      z: pose.position.z,
      qx: pose.rotation.x,
      qy: pose.rotation.y,
      qz: pose.rotation.z,
      qw: pose.rotation.w,
    );
  }

  double distanceMeters({
    required JejakuGeoOrigin origin,
    required JejakuGeoAnchor anchor,
  }) {
    return ARGeospatialProjector(
      earthRadiusMeters: earthRadiusMeters,
    ).distanceMeters(
      origin: origin.toARGeoOrigin(),
      anchor: anchor.toARGeospatialAnchor(),
    );
  }
}
