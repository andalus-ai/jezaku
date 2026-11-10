import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_geo_service.dart';

/// Development fallback origin (Bandung) used until a real fix is available.
const fallbackViewerLatitude = -6.9175;
const fallbackViewerLongitude = 107.6191;

/// Where the viewer is, for discovery and trail origins.
///
/// [isLive] is false for the fallback origin. When it is false, callers keep
/// using each memory's `distanceLabel` (which the sample data is authored
/// against); when true, distances are computed from coordinates.
class ViewerLocation {
  const ViewerLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.isLive = false,
  });

  static const fallback = ViewerLocation(
    latitude: fallbackViewerLatitude,
    longitude: fallbackViewerLongitude,
  );

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final bool isLive;

  /// Distance from the viewer to [memory] in meters.
  ///
  /// Live fixes are measured from coordinates. Without one, the memory's
  /// `distanceLabel` (authored against the fallback origin) is used.
  double? distanceToMemoryMeters(
    AnchorMemory memory, {
    AnchorGeoService geoService = const AnchorGeoService(),
  }) {
    if (isLive) {
      return geoService.distanceBetweenMeters(
        latitude,
        longitude,
        memory.latitude,
        memory.longitude,
      );
    }
    return geoService.distanceFromLabel(memory.distanceLabel);
  }

  @override
  bool operator ==(Object other) {
    return other is ViewerLocation &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.accuracyMeters == accuracyMeters &&
        other.isLive == isLive;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyMeters, isLive);
}

/// Source of viewer fixes. Injected so tests never touch platform channels.
abstract class ViewerLocationSource {
  /// Emits fixes as the viewer moves. Completes without emitting when location
  /// is unavailable (service off, permission missing, no plugin).
  Stream<ViewerLocation> watch();
}

/// Default source: no location. The app overrides it in `main.dart`.
class UnavailableViewerLocationSource implements ViewerLocationSource {
  const UnavailableViewerLocationSource();

  @override
  Stream<ViewerLocation> watch() => const Stream<ViewerLocation>.empty();
}

/// Geolocator-backed source. Never prompts for permission: the capture flow
/// owns the prompt, and discovery goes live once it has been granted.
class GeolocatorViewerLocationSource implements ViewerLocationSource {
  const GeolocatorViewerLocationSource({this.distanceFilterMeters = 10});

  final int distanceFilterMeters;

  @override
  Stream<ViewerLocation> watch() async* {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final positions = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterMeters,
        ),
      );
      await for (final position in positions) {
        final location = _fromPosition(position);
        if (location != null) {
          yield location;
        }
      }
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    } on LocationServiceDisabledException {
      return;
    }
  }

  ViewerLocation? _fromPosition(Position position) {
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
      return null;
    }
    return ViewerLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy.isFinite ? position.accuracy : null,
      isLive: true,
    );
  }
}
