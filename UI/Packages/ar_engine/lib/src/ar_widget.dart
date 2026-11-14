import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'ar_capabilities.dart';
import 'ar_controller.dart';
import 'ar_diagnostics_report.dart';
import 'ar_diagnostics_timeline.dart';
import 'ar_session_config.dart';
import 'ar_session_health.dart';
import 'ar_session_health_assessment.dart';
import 'ar_session_health_monitor.dart';
import 'exceptions/ar_exceptions.dart';

typedef ARViewCreatedCallback = void Function(ARController controller);
typedef ARSessionConfigResolvedCallback = void Function(
  ARSessionConfigResolution resolution,
);
typedef ARSessionHealthChangedCallback = void Function(
  ARSessionHealthSnapshot health,
);
typedef ARSessionHealthAssessmentChangedCallback = void Function(
  ARSessionHealthAssessment assessment,
);
typedef ARSessionDiagnosticsReportChangedCallback = void Function(
  ARDiagnosticsReport report,
);

@visibleForTesting
enum ArEnginePlatformViewBackend {
  androidPlatformView,
  iosPlatformView,
  webHtmlElementView,
  macOSPlatformView,
  desktopTexture,
  loading,
}

@visibleForTesting
bool shouldLoadArEngineDesktopTexture({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) =>
    !isWeb &&
    (targetPlatform == TargetPlatform.windows ||
        targetPlatform == TargetPlatform.linux);

@visibleForTesting
ArEnginePlatformViewBackend resolveArEnginePlatformViewBackend({
  required bool isWeb,
  required TargetPlatform targetPlatform,
  required int? desktopTextureId,
}) {
  if (isWeb) {
    return ArEnginePlatformViewBackend.webHtmlElementView;
  }
  if (targetPlatform == TargetPlatform.android) {
    return ArEnginePlatformViewBackend.androidPlatformView;
  }
  if (targetPlatform == TargetPlatform.iOS) {
    return ArEnginePlatformViewBackend.iosPlatformView;
  }
  if (targetPlatform == TargetPlatform.macOS) {
    return ArEnginePlatformViewBackend.macOSPlatformView;
  }
  if (desktopTextureId != null) {
    return ArEnginePlatformViewBackend.desktopTexture;
  }
  return ArEnginePlatformViewBackend.loading;
}

/// The Flutter widget that renders the AR camera feed and 3D scene.
///
/// Internally selects the correct platform view:
/// - **Android** → Hybrid-composition [PlatformViewLink] + [GLSurfaceView] (GLES 3)
/// - **iOS**     → [UiKitView] backed by `ARMetalPlatformView` (MTKView + ARKit)
/// - **Web**     → [HtmlElementView] backed by WebXR canvas
/// - **macOS**   → [AppKitView] backed by `NSView`
/// - **Windows / Linux** → [Texture] widget fed from the plugin's registered
///   pixel-buffer texture
///
/// The widget automatically pauses and resumes the AR session in response to
/// [AppLifecycleState] changes, and disposes it when the widget is removed.
///
/// Example:
/// ```dart
/// ARWidget(
///   config: ARSessionConfig(detectHorizontalPlanes: true),
///   onARViewCreated: (controller) => setState(() => _ctrl = controller),
/// )
/// ```
class ARWidget extends StatefulWidget {
  const ARWidget({
    super.key,
    required this.config,
    this.onARViewCreated,
    this.loadingWidget,
    this.errorBuilder,
    this.consumeGestures = true,
    this.resolveConfigAgainstCapabilities = false,
    this.onSessionConfigResolved,
    this.onSessionHealthChanged,
    this.onSessionHealthAssessmentChanged,
    this.onSessionDiagnosticsReportChanged,
    this.sessionDiagnosticsReportQuery = const ARDiagnosticsTimelineQuery(),
    this.sessionHealthPolicy = const ARSessionHealthPolicy(),
    this.sessionHealthMinPublishInterval = const Duration(milliseconds: 500),
    this.sessionHealthResampleInterval = const Duration(seconds: 1),
  });

  /// Configuration applied to the AR session on first creation.
  final ARSessionConfig config;

  /// Callback delivered once the session is running and ready.
  final ARViewCreatedCallback? onARViewCreated;

  /// Widget shown while the AR session is initialising.
  /// Defaults to a centred [CircularProgressIndicator].
  final Widget? loadingWidget;

  /// Builder called when the session fails to start.
  /// Receives the thrown error. Defaults to a red error message.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// If true, all pointer events are forwarded to the AR platform view.
  /// Set to false if you place interactive Flutter widgets on top.
  final bool consumeGestures;

  /// Resolve [config] against native capabilities before creating/reconfiguring
  /// the session.
  ///
  /// When enabled, unsupported optional features are disabled before reaching
  /// the native backend. [onSessionConfigResolved] receives the resolution
  /// report for observability.
  final bool resolveConfigAgainstCapabilities;

  /// Called whenever [config] is resolved and applied to the native session.
  final ARSessionConfigResolvedCallback? onSessionConfigResolved;

  /// Called with throttled runtime health snapshots while the session is active.
  ///
  /// The snapshot is sampled from controller camera, plane, anchor, and light
  /// streams. Omit this callback and the other session diagnostics callbacks to
  /// avoid creating a health monitor.
  final ARSessionHealthChangedCallback? onSessionHealthChanged;

  /// Called with policy-assessed runtime health while the session is active.
  ///
  /// Use this when you want severity, issue flags, and ready-to-display labels
  /// instead of manually applying [sessionHealthPolicy] to raw snapshots.
  final ARSessionHealthAssessmentChangedCallback?
      onSessionHealthAssessmentChanged;

  /// Called with a live diagnostics report built from the session health
  /// timeline.
  ///
  /// Use [sessionDiagnosticsReportQuery] to pre-filter the report's
  /// [ARDiagnosticsReport.queryResult] without changing the underlying
  /// timeline.
  final ARSessionDiagnosticsReportChangedCallback?
      onSessionDiagnosticsReportChanged;

  /// Query used when building reports for
  /// [onSessionDiagnosticsReportChanged].
  final ARDiagnosticsTimelineQuery sessionDiagnosticsReportQuery;

  /// Policy used for [onSessionHealthAssessmentChanged].
  final ARSessionHealthPolicy sessionHealthPolicy;

  /// Minimum delay between [onSessionHealthChanged] callbacks.
  final Duration sessionHealthMinPublishInterval;

  /// Periodic runtime-health resample cadence.
  ///
  /// This lets stale camera-frame detection surface even when native streams
  /// stop producing events. Set to `null` or [Duration.zero] to disable.
  final Duration? sessionHealthResampleInterval;

  @override
  State<ARWidget> createState() => _ARWidgetState();
}

class _ARWidgetState extends State<ARWidget> with WidgetsBindingObserver {
  ARController? _controller;
  Object? _error;
  bool _initialising = true;
  bool _resumeInProgress = false;
  int? _desktopTextureId;
  ARSessionConfig? _platformViewConfig;
  ARSessionHealthMonitor? _sessionHealthMonitor;
  StreamSubscription<ARSessionHealthSnapshot>? _sessionHealthSubscription;
  StreamSubscription<ARSessionHealthAssessment>?
      _sessionHealthAssessmentSubscription;
  StreamSubscription<ARDiagnosticsTimeline>?
      _sessionDiagnosticsReportSubscription;
  int _sessionEpoch = 0;
  int _configEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAR();
  }

  @override
  void didUpdateWidget(covariant ARWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.onSessionHealthChanged == null) !=
            (widget.onSessionHealthChanged == null) ||
        (oldWidget.onSessionHealthAssessmentChanged == null) !=
            (widget.onSessionHealthAssessmentChanged == null) ||
        (oldWidget.onSessionDiagnosticsReportChanged == null) !=
            (widget.onSessionDiagnosticsReportChanged == null) ||
        oldWidget.sessionHealthPolicy != widget.sessionHealthPolicy ||
        oldWidget.sessionHealthMinPublishInterval !=
            widget.sessionHealthMinPublishInterval ||
        oldWidget.sessionHealthResampleInterval !=
            widget.sessionHealthResampleInterval) {
      _bindSessionHealthMonitor(_controller);
    } else if (oldWidget.sessionDiagnosticsReportQuery !=
        widget.sessionDiagnosticsReportQuery) {
      final monitor = _sessionHealthMonitor;
      if (monitor != null) {
        _emitSessionDiagnosticsReport(monitor);
      }
    }
    if (oldWidget.config == widget.config &&
        oldWidget.resolveConfigAgainstCapabilities ==
            widget.resolveConfigAgainstCapabilities) {
      return;
    }

    final controller = _controller;
    if (controller != null && _error == null) {
      _reconfigureAR(controller, widget.config);
      return;
    }

    if (!_initialising) {
      setState(() {
        _error = null;
        _initialising = true;
      });
      _initAR();
    }
  }

  // ── AR session init ────────────────────────────────────────────────────────

  Future<void> _initAR() async {
    final epoch = ++_sessionEpoch;
    ARController? controller;
    ARSessionConfigResolution? configResolution;
    try {
      final initialConfig = widget.config;
      final initialResolveConfig = widget.resolveConfigAgainstCapabilities;
      var platformViewConfig = initialConfig;
      if (initialResolveConfig) {
        final session = await ARController.createResolved(initialConfig);
        controller = session.controller;
        configResolution = session.configResolution;
        platformViewConfig = session.resolvedConfig;
      } else {
        controller = await ARController.create(initialConfig);
      }

      if (!mounted || epoch != _sessionEpoch) {
        _disposeController(controller);
        return;
      }

      if (initialConfig != widget.config ||
          initialResolveConfig != widget.resolveConfigAgainstCapabilities) {
        final runtimeConfig = await _runtimeConfigFor(widget.config);
        configResolution = runtimeConfig.resolution;
        await controller.reconfigure(runtimeConfig.config);
        platformViewConfig = runtimeConfig.config;
      }

      // For desktop texture platforms, fetch the registered texture ID before
      // rendering. macOS uses an AppKit platform view instead.
      int? texId;
      if (shouldLoadArEngineDesktopTexture(
        isWeb: kIsWeb,
        targetPlatform: defaultTargetPlatform,
      )) {
        texId = await controller.getDesktopTextureId();
      }

      if (!mounted || epoch != _sessionEpoch) {
        _disposeController(controller);
        return;
      }
      setState(() {
        _controller = controller;
        _desktopTextureId = texId;
        _platformViewConfig = platformViewConfig;
        _initialising = false;
      });
      _notifyConfigResolved(configResolution);
      _bindSessionHealthMonitor(controller);
      widget.onARViewCreated?.call(controller);
    } on ARNotSupportedException catch (e) {
      _disposeController(controller);
      _setError(e);
    } on ARCameraPermissionException catch (e) {
      _disposeController(controller);
      _setError(e);
    } on ARSessionInitException catch (e) {
      _disposeController(controller);
      _setError(e);
    } on PlatformException catch (e) {
      _disposeController(controller);
      if (e.code == 'CAMERA_PERMISSION_DENIED') {
        _setError(
          ARCameraPermissionException(
            e.message ?? 'Camera permission is required for AR.',
          ),
        );
      } else {
        _setError(
          ARSessionInitException(
            e.message ?? 'Native AR session initialisation failed.',
            e,
          ),
        );
      }
    } on Object catch (e) {
      _disposeController(controller);
      _setError(e);
    }
  }

  Future<void> _reconfigureAR(
    ARController controller,
    ARSessionConfig config,
  ) async {
    final epoch = ++_configEpoch;
    try {
      final runtimeConfig = await _runtimeConfigFor(config);
      await controller.reconfigure(runtimeConfig.config);
      if (!mounted || epoch != _configEpoch || controller != _controller) {
        return;
      }
      _desktopTextureId = null;
      if (shouldLoadArEngineDesktopTexture(
        isWeb: kIsWeb,
        targetPlatform: defaultTargetPlatform,
      )) {
        _desktopTextureId = await controller.getDesktopTextureId();
      }
      if (!mounted || epoch != _configEpoch || controller != _controller) {
        return;
      }
      setState(() {
        _platformViewConfig = runtimeConfig.config;
      });
      _notifyConfigResolved(runtimeConfig.resolution);
    } on Object catch (e) {
      if (!mounted || epoch != _configEpoch || controller != _controller) {
        return;
      }
      _setError(e);
    }
  }

  Future<_ARRuntimeConfig> _runtimeConfigFor(ARSessionConfig config) async {
    if (!widget.resolveConfigAgainstCapabilities) {
      return _ARRuntimeConfig(config: config);
    }
    final resolution = await ARController.resolveSessionConfig(config);
    return _ARRuntimeConfig(
      config: resolution.resolvedConfig,
      resolution: resolution,
    );
  }

  void _notifyConfigResolved(ARSessionConfigResolution? resolution) {
    if (resolution == null || !mounted) {
      return;
    }
    widget.onSessionConfigResolved?.call(resolution);
  }

  void _setError(Object e) {
    if (!mounted) return;
    setState(() {
      _error = e;
      _initialising = false;
    });
  }

  // ── App lifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _runControllerLifecycleCall((controller) => controller.pause());
        break;
      case AppLifecycleState.resumed:
        unawaited(_resumeOrRecreateSession());
        break;
      default:
        break;
    }
  }

  /// Resume the active native session. Some AR runtimes cannot recover
  /// after the camera was reclaimed while the app was backgrounded; in that
  /// case rebuild the controller instead of leaving the viewer in an error
  /// state.
  Future<void> _resumeOrRecreateSession() async {
    final controller = _controller;
    if (controller == null ||
        _error != null ||
        _initialising ||
        _resumeInProgress) {
      return;
    }
    _resumeInProgress = true;
    try {
      await controller.resume();
    } on Object {
      if (!mounted || controller != _controller) {
        return;
      }
      await _recreateSessionAfterResumeFailure(controller);
    } finally {
      _resumeInProgress = false;
    }
  }

  Future<void> _recreateSessionAfterResumeFailure(
    ARController previousController,
  ) async {
    if (!mounted || previousController != _controller) {
      return;
    }
    setState(() {
      _controller = null;
      _error = null;
      _initialising = true;
      _desktopTextureId = null;
      _platformViewConfig = null;
    });
    _disposeSessionHealthMonitor();
    try {
      await previousController.dispose();
    } on Object {
      // Continue with a fresh controller even if native teardown failed.
    }
    if (!mounted) {
      return;
    }
    await _initAR();
  }

  void _runControllerLifecycleCall(
    Future<void> Function(ARController controller) call,
  ) {
    final controller = _controller;
    if (controller == null || _error != null) return;
    unawaited(_guardControllerLifecycleCall(controller, call));
  }

  Future<void> _guardControllerLifecycleCall(
    ARController controller,
    Future<void> Function(ARController controller) call,
  ) async {
    try {
      await call(controller);
    } on Object catch (e) {
      if (mounted && controller == _controller) {
        _setError(e);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionEpoch += 1;
    _configEpoch += 1;
    _disposeSessionHealthMonitor();
    _disposeController(_controller);
    super.dispose();
  }

  void _disposeController(ARController? controller) {
    if (controller == null) return;
    try {
      unawaited(
        controller.dispose().catchError((Object _, StackTrace __) {
          // Disposal is best-effort during widget teardown and stale init.
        }),
      );
    } on Object {
      // The controller may already be half-disposed by a competing teardown.
    }
  }

  void _bindSessionHealthMonitor(ARController? controller) {
    _disposeSessionHealthMonitor();
    if (controller == null ||
        (widget.onSessionHealthChanged == null &&
            widget.onSessionHealthAssessmentChanged == null &&
            widget.onSessionDiagnosticsReportChanged == null)) {
      return;
    }
    final monitor = ARSessionHealthMonitor(
      controller: controller,
      minPublishInterval: widget.sessionHealthMinPublishInterval,
      resampleInterval: widget.sessionHealthResampleInterval,
      healthPolicy: widget.sessionHealthPolicy,
      includeRuntimeDiagnostics:
          widget.onSessionDiagnosticsReportChanged != null,
    );
    _sessionHealthMonitor = monitor;
    if (widget.onSessionHealthChanged != null) {
      _sessionHealthSubscription = monitor.snapshots.listen(
        (health) {
          if (!mounted || monitor != _sessionHealthMonitor) {
            return;
          }
          widget.onSessionHealthChanged?.call(health);
        },
        onError: (Object _) {},
      );
    }
    if (widget.onSessionHealthAssessmentChanged != null) {
      _sessionHealthAssessmentSubscription = monitor.assessments.listen(
        (assessment) {
          if (!mounted || monitor != _sessionHealthMonitor) {
            return;
          }
          widget.onSessionHealthAssessmentChanged?.call(assessment);
        },
        onError: (Object _) {},
      );
    }
    if (widget.onSessionDiagnosticsReportChanged != null) {
      _sessionDiagnosticsReportSubscription =
          monitor.diagnosticsTimelineChanges.listen(
        (_) => _emitSessionDiagnosticsReport(monitor),
        onError: (Object _) {},
      );
    }
  }

  void _emitSessionDiagnosticsReport(ARSessionHealthMonitor monitor) {
    if (!mounted || monitor != _sessionHealthMonitor) {
      return;
    }
    widget.onSessionDiagnosticsReportChanged?.call(
      monitor.toReport(query: widget.sessionDiagnosticsReportQuery),
    );
  }

  void _disposeSessionHealthMonitor() {
    unawaited(_sessionHealthSubscription?.cancel());
    _sessionHealthSubscription = null;
    unawaited(_sessionHealthAssessmentSubscription?.cancel());
    _sessionHealthAssessmentSubscription = null;
    unawaited(_sessionDiagnosticsReportSubscription?.cancel());
    _sessionDiagnosticsReportSubscription = null;
    final monitor = _sessionHealthMonitor;
    _sessionHealthMonitor = null;
    unawaited(monitor?.dispose());
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_initialising) {
      return widget.loadingWidget ?? const _DefaultLoader();
    }
    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!) ??
          _DefaultError(error: _error!);
    }
    return _buildPlatformView();
  }

  Widget _buildPlatformView() {
    const viewType = 'com.arengine/ar_view';

    switch (resolveArEnginePlatformViewBackend(
      isWeb: kIsWeb,
      targetPlatform: defaultTargetPlatform,
      desktopTextureId: _desktopTextureId,
    )) {
      case ArEnginePlatformViewBackend.androidPlatformView:
        return _buildAndroidPlatformView(viewType);
      case ArEnginePlatformViewBackend.iosPlatformView:
        return _buildIOSPlatformView(viewType);
      case ArEnginePlatformViewBackend.webHtmlElementView:
        return const HtmlElementView(viewType: viewType);
      case ArEnginePlatformViewBackend.macOSPlatformView:
        return _buildMacOSPlatformView(viewType);
      case ArEnginePlatformViewBackend.desktopTexture:
        return Texture(
          textureId: _desktopTextureId!,
          filterQuality: FilterQuality.high,
        );
      case ArEnginePlatformViewBackend.loading:
        return const _DefaultLoader();
    }
  }

  Widget _buildAndroidPlatformView(String viewType) {
    final config = _platformViewConfig ?? widget.config;
    final gestureRecognizers = widget.consumeGestures
        ? <Factory<OneSequenceGestureRecognizer>>{
            const Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
          }
        : const <Factory<OneSequenceGestureRecognizer>>{};

    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (ctx, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: gestureRecognizers,
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) =>
          PlatformViewsService.initExpensiveAndroidView(
        id: params.id,
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: config.toMap(),
        creationParamsCodec: const StandardMessageCodec(),
        onFocus: () => params.onFocusChanged(true),
      )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..create(),
    );
  }

  Widget _buildIOSPlatformView(String viewType) {
    final config = _platformViewConfig ?? widget.config;
    return UiKitView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: config.toMap(),
      creationParamsCodec: const StandardMessageCodec(),
      gestureRecognizers: widget.consumeGestures
          ? <Factory<OneSequenceGestureRecognizer>>{
              const Factory<EagerGestureRecognizer>(
                EagerGestureRecognizer.new,
              ),
            }
          : null,
    );
  }

  Widget _buildMacOSPlatformView(String viewType) {
    final config = _platformViewConfig ?? widget.config;
    return AppKitView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: config.toMap(),
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}

class _ARRuntimeConfig {
  const _ARRuntimeConfig({
    required this.config,
    this.resolution,
  });

  final ARSessionConfig config;
  final ARSessionConfigResolution? resolution;
}

// ── Default loading and error widgets ─────────────────────────────────────────

class _DefaultLoader extends StatelessWidget {
  const _DefaultLoader();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white54),
              SizedBox(height: 14),
              Text(
                'Starting AR session…',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
}

class _DefaultError extends StatelessWidget {
  const _DefaultError({required this.error});

  final Object error;

  String get _message {
    if (error is ARNotSupportedException) {
      return 'Augmented Reality is not supported on this device.';
    }
    if (error is ARCameraPermissionException) {
      return 'Camera permission is required for AR.\n'
          'Please grant it in Settings and restart the app.';
    }
    if (error is ARSessionInitException) {
      return 'Failed to start AR session:\n${(error as ARSessionInitException).message}';
    }
    return 'AR error: $error';
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  error is ARNotSupportedException
                      ? Icons.no_photography
                      : Icons.error_outline,
                  color: Colors.redAccent,
                  size: 52,
                ),
                const SizedBox(height: 16),
                Text(
                  _message,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}
