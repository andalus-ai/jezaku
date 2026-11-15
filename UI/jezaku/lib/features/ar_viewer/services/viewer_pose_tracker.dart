import 'dart:async';

import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jejaku/app/utils/bounded_timers.dart';
import 'package:jejaku/features/ar_viewer/services/viewer_geo.dart';

/// The location capabilities the viewer needs, behind an interface so the
/// tracker can be tested without a platform channel.
abstract interface class ViewerLocationGateway {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Stream<Position> positionStream();
}

class GeolocatorViewerLocationGateway implements ViewerLocationGateway {
  const GeolocatorViewerLocationGateway();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    );
  }
}

/// Compass headings in degrees, or null when the device has no compass.
typedef ViewerCompassSource = Stream<double?>? Function();

/// The plugin's compass stream reduced to a heading, preferring the value
/// corrected for camera orientation.
Stream<double?>? flutterCompassHeadings() {
  return FlutterCompass.events?.map(
    (event) => event.headingForCameraMode ?? event.heading,
  );
}

/// Owns the live compass and GPS subscriptions of the AR viewer and reports
/// readings through callbacks. It knows nothing about widgets or providers.
class ViewerPoseTracker {
  ViewerPoseTracker({
    required this.onHeading,
    required this.onPosition,
    required BoundedTimers timers,
    ViewerLocationGateway location = const GeolocatorViewerLocationGateway(),
    ViewerCompassSource compass = flutterCompassHeadings,
  })  : _timers = timers,
        _location = location,
        _compass = compass;

  /// Called with each finite heading, already normalised to [0, 360).
  final void Function(double headingDegrees) onHeading;
  final void Function(Position position) onPosition;

  final BoundedTimers _timers;
  final ViewerLocationGateway _location;
  final ViewerCompassSource _compass;

  StreamSubscription<double?>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;

  bool get isTrackingCompass => _compassSubscription != null;
  bool get isTrackingPosition => _positionSubscription != null;

  void startCompass() {
    unawaited(_compassSubscription?.cancel());
    _compassSubscription = null;
    final headings = _compass();
    if (headings == null) {
      return;
    }
    _compassSubscription = headings.listen(
      (heading) {
        if (heading == null || !heading.isFinite) {
          return;
        }
        onHeading(ViewerGeo.normalizeHeading(heading));
      },
      onError: (Object _) {},
      cancelOnError: false,
    );
  }

  /// Starts GPS updates once location is enabled and permitted. [isActive] is
  /// checked after every await so a disposed owner is never called back.
  Future<void> startPosition({required bool Function() isActive}) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (!isActive()) {
      return;
    }
    try {
      final serviceEnabled = await _timers.run(
        _location.isServiceEnabled(),
        const Duration(milliseconds: 700),
        onTimeout: () => false,
      );
      if (!isActive() || !serviceEnabled) {
        return;
      }
      var permission = await _timers.run(
        _location.checkPermission(),
        const Duration(milliseconds: 700),
      );
      if (permission == LocationPermission.denied) {
        permission = await _timers.run(
          _location.requestPermission(),
          const Duration(seconds: 2),
        );
      }
      if (!isActive() ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _positionSubscription = _location.positionStream().listen(
            onPosition,
            onError: (Object _) {},
            cancelOnError: false,
          );
    } on Object {
      // The caller's periodic sensor refresh remains as a slower fallback.
    }
  }

  /// Stops both streams (for example while the app is in the background).
  void stop() {
    unawaited(_compassSubscription?.cancel());
    _compassSubscription = null;
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
  }
}
