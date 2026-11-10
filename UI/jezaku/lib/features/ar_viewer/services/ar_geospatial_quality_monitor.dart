import 'dart:async';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

/// Polls the native geospatial status and publishes how trustworthy memory
/// placement currently is.
///
/// The AR viewer shows the result to the user, and uses [onFirstPrecise] to
/// move memories from the approximate GPS projection to native geospatial
/// anchors. The upgrade is one-way for the lifetime of a monitor: native
/// anchors keep correcting themselves, so a brief accuracy dip must not
/// push placed memories back to the worse projection.
class ARGeospatialQualityMonitor {
  ARGeospatialQualityMonitor({
    required this.readStatus,
    this.policy = const JejakuPlacementPolicy(),
    this.interval = const Duration(seconds: 2),
    this.onFirstPrecise,
    ValueNotifier<JejakuPlacementAssessment>? assessment,
  }) : assessment = assessment ??
            ValueNotifier<JejakuPlacementAssessment>(
              const JejakuPlacementAssessment.initial(),
            );

  /// Reads the native geospatial status, usually
  /// `ARController.getGeospatialStatus`.
  final Future<ARGeospatialStatus> Function() readStatus;

  final JejakuPlacementPolicy policy;
  final Duration interval;

  /// Called once, the first time the assessment becomes precise.
  final FutureOr<void> Function()? onFirstPrecise;

  /// Latest assessment. Only notifies when the value actually changes.
  final ValueNotifier<JejakuPlacementAssessment> assessment;

  Timer? _timer;
  bool _polling = false;
  bool _disposed = false;
  bool _hasBeenPrecise = false;
  ARVpsAvailability? _vps;

  /// Whether the assessment has been precise at any point.
  bool get hasBeenPrecise => _hasBeenPrecise;

  bool get isRunning => _timer?.isActive ?? false;

  /// Records a VPS availability result as context for [policy].
  void setVpsAvailability(ARVpsAvailability value) {
    _vps = value;
  }

  /// Starts polling. Calling this while running does nothing.
  void start() {
    if (_disposed || isRunning) {
      return;
    }
    _timer = Timer.periodic(interval, (_) => unawaited(poll()));
    unawaited(poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Reads the status once and updates [assessment]. Overlapping calls are
  /// ignored so a slow native call cannot queue up.
  Future<void> poll() async {
    if (_disposed || _polling) {
      return;
    }
    _polling = true;
    try {
      ARGeospatialStatus? status;
      try {
        status = await readStatus();
      } on Object {
        // A failed read is "no information", never "precise".
        status = null;
      }
      if (_disposed) {
        return;
      }
      final next = policy.assess(status: status, vps: _vps);
      if (next != assessment.value) {
        assessment.value = next;
      }
      if (next.isPrecise && !_hasBeenPrecise) {
        _hasBeenPrecise = true;
        try {
          await onFirstPrecise?.call();
        } on Object {
          // The upgrade is best effort; the next sync can retry placement.
        }
      }
    } finally {
      _polling = false;
    }
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}
