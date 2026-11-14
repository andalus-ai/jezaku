import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/camera/widgets/live_camera_preview.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/camera');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows the error state when no camera is available and retries',
      (tester) async {
    var availableCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'availableCameras') {
        availableCalls += 1;
        return <Object?>[];
      }
      return null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LiveCameraPreview(
          fallback: const Text('preparing'),
          errorBuilder: (context, error, retry) => TextButton(
            onPressed: retry,
            child: const Text('Try again'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    expect(availableCalls, 1);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(availableCalls, 2);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('without an errorBuilder the fallback is kept', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel,
        (call) async {
      return call.method == 'availableCameras' ? <Object?>[] : null;
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: LiveCameraPreview(fallback: Text('preparing')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('preparing'), findsOneWidget);
  });
}
