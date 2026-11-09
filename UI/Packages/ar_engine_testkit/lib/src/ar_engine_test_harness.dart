import 'package:ar_engine/ar_engine.dart';

import 'test_ar_engine_platform.dart';

class ArEngineTestHarness {
  ArEngineTestHarness._({
    required this.platform,
    required ArEnginePlatform originalPlatform,
  }) : _originalPlatform = originalPlatform;

  final TestArEnginePlatform platform;
  final ArEnginePlatform _originalPlatform;
  bool _restored = false;

  static ArEngineTestHarness install({TestArEnginePlatform? platform}) {
    final originalPlatform = ArEnginePlatform.instance;
    final installedPlatform = platform ?? TestArEnginePlatform();
    ArEnginePlatform.instance = installedPlatform;
    return ArEngineTestHarness._(
      platform: installedPlatform,
      originalPlatform: originalPlatform,
    );
  }

  Future<ARController> createController([
    ARSessionConfig config = const ARSessionConfig(),
  ]) {
    return ARController.create(config);
  }

  Future<ARResolvedSession> createResolvedController([
    ARSessionConfig config = const ARSessionConfig(),
  ]) {
    return ARController.createResolved(config);
  }

  void restore() {
    if (_restored) {
      return;
    }
    _restored = true;
    ArEnginePlatform.instance = _originalPlatform;
  }
}
