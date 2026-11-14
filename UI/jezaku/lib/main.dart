import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/app_error_handling.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/ar_viewer/services/ar_model_asset_cache_provider.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_export_bundle_store.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_store.dart';
import 'package:jejaku/features/camera/services/ar_capture_diagnostics_cache_store.dart';
import 'package:jejaku/features/home/services/anchor_media_repository_bootstrap.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/sync/services/anchor_sync_delivery_log_store.dart';
import 'package:jejaku/features/sync/services/anchor_media_upload_queue_store.dart';
import 'package:jejaku/features/trails/services/ar_trail_progress_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  installGlobalErrorHandlers();
  _start();
}

Future<void> _start() async {
  try {
    await _bootstrapAndRun();
  } on Object catch (error, stackTrace) {
    appErrorBuffer.record(error, stackTrace, source: 'startup');
    runApp(StartupFailureApp(onRetry: _start));
  }
}

Future<void> _bootstrapAndRun() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final appSupportDirectory = await getApplicationSupportDirectory();
  final mediaStorageDirectory =
      anchorMediaStorageDirectory(appSupportDirectory);
  final modelCacheDirectory = arModelAssetCacheDirectory(appSupportDirectory);
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        viewerLocationSourceProvider.overrideWithValue(
          const GeolocatorViewerLocationSource(),
        ),
        persistentAnchorMediaRepositoryOverride(
          rootDirectory: mediaStorageDirectory,
        ),
        persistentARModelAssetCacheOverride(
          rootDirectory: modelCacheDirectory,
        ),
        persistentAnchorMemoryStoreOverride(
          preferences: preferences,
        ),
        persistentAnchorMediaUploadQueueStoreOverride(
          preferences: preferences,
        ),
        persistentAnchorSyncDeliveryLogStoreOverride(
          preferences: preferences,
        ),
        persistentARTrailProgressStoreOverride(
          preferences: preferences,
        ),
        persistentARMemorySceneDiagnosticsStoreOverride(
          preferences: preferences,
        ),
        persistentARSceneDiagnosticsExportBundleCacheStoreOverride(
          preferences: preferences,
        ),
        persistentARCaptureDiagnosticsCacheStoreOverride(
          preferences: preferences,
        ),
      ],
      child: const JejakuApp(),
    ),
  );
}

class JejakuApp extends ConsumerWidget {
  const JejakuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(arModelAssetCacheStartupMaintenanceProvider);
    return MaterialApp(
      title: 'Jejaku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
      ),
      initialRoute: AppRoutes.root,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
