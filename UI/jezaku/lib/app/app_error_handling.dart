import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One captured error, kept in memory for diagnostics and support reports.
class AppErrorRecord {
  const AppErrorRecord({
    required this.source,
    required this.message,
    required this.stackTrace,
    required this.recordedAt,
  });

  final String source;
  final String message;
  final String stackTrace;
  final DateTime recordedAt;
}

/// Bounded in-memory log of unexpected errors (newest last).
class AppErrorBuffer {
  AppErrorBuffer({this.capacity = 50, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final int capacity;
  final DateTime Function() _now;
  final List<AppErrorRecord> _records = <AppErrorRecord>[];

  List<AppErrorRecord> get records => List.unmodifiable(_records);

  void record(Object error, StackTrace? stackTrace, {String source = 'app'}) {
    _records.add(
      AppErrorRecord(
        source: source,
        message: error.toString(),
        stackTrace: (stackTrace ?? StackTrace.empty).toString(),
        recordedAt: _now(),
      ),
    );
    while (_records.length > capacity) {
      _records.removeAt(0);
    }
  }

  void clear() => _records.clear();
}

final AppErrorBuffer appErrorBuffer = AppErrorBuffer();

/// Routes framework and platform errors into [buffer] instead of letting them
/// disappear, and replaces the red error screen with a calm one in release.
///
/// Debug builds keep Flutter's default console output and red screen.
void installGlobalErrorHandlers({AppErrorBuffer? buffer}) {
  final target = buffer ?? appErrorBuffer;

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    target.record(details.exception, details.stack, source: 'flutter');
    if (previousOnError != null) {
      previousOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    target.record(error, stack, source: 'platform');
    // Report handled so the engine does not terminate the app.
    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const FriendlyErrorWidget();
    };
  }
}

/// Shown in place of a widget that failed to build, in release builds.
class FriendlyErrorWidget extends StatelessWidget {
  const FriendlyErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFF5F5F5),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Color(0xFF757575), size: 32),
                SizedBox(height: 8),
                Text(
                  'Something went wrong here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF424242),
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when startup itself fails (storage unavailable, bad install, ...)
/// instead of leaving the user on a blank screen.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jejaku',
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Jejaku could not start',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Something on this device stopped the app from loading '
                    'its data. Your memories have not been deleted. Try '
                    'again, and restart your phone if it keeps happening.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
