import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class LiveCameraPreview extends StatefulWidget {
  const LiveCameraPreview({
    super.key,
    this.fallback,
    this.onReady,
    this.onError,
  });

  final Widget? fallback;
  final ValueChanged<CameraController>? onReady;
  final ValueChanged<Object>? onError;

  @override
  LiveCameraPreviewState createState() => LiveCameraPreviewState();
}

class LiveCameraPreviewState extends State<LiveCameraPreview>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeFuture;
  Object? _error;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFuture = _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(controller.pausePreview().catchError((Object _) {}));
    } else if (state == AppLifecycleState.resumed &&
        controller.value.isInitialized) {
      unawaited(controller.resumePreview().catchError((Object _) {}));
    }
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NO_CAMERA', 'No camera found on this device.');
      }
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      widget.onReady?.call(controller);
      setState(() => _error = null);
    } on Object catch (error) {
      widget.onError?.call(error);
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  Future<Uint8List?> captureJpeg() async {
    final controller = _controller;
    if (_isCapturing ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return null;
    }
    _isCapturing = true;
    try {
      final file = await controller
          .takePicture()
          .timeout(const Duration(milliseconds: 1600));
      return await file.readAsBytes();
    } on Object catch (error) {
      widget.onError?.call(error);
      return null;
    } finally {
      _isCapturing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        final controller = _controller;
        if (snapshot.connectionState != ConnectionState.done ||
            controller == null ||
            !controller.value.isInitialized ||
            _error != null) {
          return widget.fallback ?? const ColoredBox(color: Colors.black);
        }
        return _CoverCameraPreview(controller: controller);
      },
    );
  }
}

class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final previewSize = controller.value.previewSize;
        if (size.isEmpty || previewSize == null) {
          return CameraPreview(controller);
        }

        final isPortrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        final previewWidth =
            isPortrait ? previewSize.height : previewSize.width;
        final previewHeight =
            isPortrait ? previewSize.width : previewSize.height;

        return ClipRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}
