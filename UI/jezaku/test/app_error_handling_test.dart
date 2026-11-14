import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/app_error_handling.dart';

void main() {
  test('error buffer keeps the newest records within capacity', () {
    final buffer = AppErrorBuffer(
      capacity: 2,
      now: () => DateTime.utc(2026, 6, 1),
    );

    buffer.record(StateError('first'), StackTrace.current, source: 'a');
    buffer.record(StateError('second'), null, source: 'b');
    buffer.record(StateError('third'), null, source: 'c');

    expect(buffer.records.map((record) => record.source), ['b', 'c']);
    expect(buffer.records.last.message, contains('third'));
    expect(buffer.records.last.recordedAt, DateTime.utc(2026, 6, 1));

    buffer.clear();
    expect(buffer.records, isEmpty);
  });

  testWidgets('friendly error widget renders without a Material ancestor',
      (tester) async {
    await tester.pumpWidget(const FriendlyErrorWidget());

    expect(find.text('Something went wrong here.'), findsOneWidget);
  });

  testWidgets('startup failure screen offers a retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(StartupFailureApp(onRetry: () => retries++));

    expect(find.text('Jejaku could not start'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('installed handlers record framework errors', (tester) async {
    final buffer = AppErrorBuffer();
    final originalOnError = FlutterError.onError;
    final originalPlatformOnError = PlatformDispatcher.instance.onError;
    try {
      // Keep the test binding from failing the test on the reported error.
      FlutterError.onError = (_) {};

      installGlobalErrorHandlers(buffer: buffer);
      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('boom')),
      );
      final handled = PlatformDispatcher.instance.onError!(
        StateError('async boom'),
        StackTrace.current,
      );

      expect(handled, isTrue);
      expect(buffer.records.map((record) => record.source),
          ['flutter', 'platform']);
      expect(buffer.records.first.message, contains('boom'));
    } finally {
      FlutterError.onError = originalOnError;
      PlatformDispatcher.instance.onError = originalPlatformOnError;
    }
  });
}
