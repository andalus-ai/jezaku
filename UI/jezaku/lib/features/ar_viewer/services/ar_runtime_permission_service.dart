import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class ARRuntimePermissions {
  const ARRuntimePermissions({
    required this.cameraStatus,
    required this.locationStatus,
  });

  const ARRuntimePermissions.granted()
      : cameraStatus = PermissionStatus.granted,
        locationStatus = PermissionStatus.granted;

  const ARRuntimePermissions.denied()
      : cameraStatus = PermissionStatus.denied,
        locationStatus = PermissionStatus.denied;

  final PermissionStatus cameraStatus;
  final PermissionStatus locationStatus;

  bool get cameraGranted => cameraStatus.isGranted || cameraStatus.isLimited;

  bool get locationGranted =>
      locationStatus.isGranted || locationStatus.isLimited;

  bool get shouldOpenSettings {
    return cameraStatus.isPermanentlyDenied ||
        cameraStatus.isRestricted ||
        locationStatus.isPermanentlyDenied ||
        locationStatus.isRestricted;
  }

  String get statusLabel {
    if (!cameraGranted) {
      return 'Camera permission needed';
    }
    if (!locationGranted) {
      return 'Live AR ready, geospatial off';
    }
    return 'Live AR ready';
  }

  String get guidanceLabel {
    if (!cameraGranted) {
      return 'Allow camera access so ARCore can start the live preview.';
    }
    if (!locationGranted) {
      return 'Allow location access to place nearby memories with geospatial anchors.';
    }
    return 'Camera and location access are ready.';
  }

  ARSessionConfig applyToSessionConfig(ARSessionConfig config) {
    if (locationGranted || !config.geospatialEnabled) {
      return config;
    }
    return config.copyWith(geospatialEnabled: false);
  }
}

class ARRuntimePermissionService {
  const ARRuntimePermissionService();

  Future<ARRuntimePermissions> request() async {
    if (!usesMobileRuntimePermissions) {
      return const ARRuntimePermissions.granted();
    }
    try {
      final cameraStatus = await _requestIfNeeded(Permission.camera);
      final locationStatus = await _requestIfNeeded(_locationPermission);
      return ARRuntimePermissions(
        cameraStatus: cameraStatus,
        locationStatus: locationStatus,
      );
    } on MissingPluginException {
      return const ARRuntimePermissions.granted();
    } on Object {
      return const ARRuntimePermissions.denied();
    }
  }

  Future<ARRuntimePermissions> check() async {
    if (!usesMobileRuntimePermissions) {
      return const ARRuntimePermissions.granted();
    }
    try {
      return ARRuntimePermissions(
        cameraStatus: await Permission.camera.status,
        locationStatus: await _locationPermission.status,
      );
    } on MissingPluginException {
      return const ARRuntimePermissions.granted();
    } on Object {
      return const ARRuntimePermissions.denied();
    }
  }

  bool get usesMobileRuntimePermissions {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  Permission get _locationPermission {
    return defaultTargetPlatform == TargetPlatform.android
        ? Permission.location
        : Permission.locationWhenInUse;
  }

  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } on MissingPluginException {
      return false;
    }
  }

  Future<PermissionStatus> _requestIfNeeded(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) {
      return status;
    }
    return permission.request();
  }
}
