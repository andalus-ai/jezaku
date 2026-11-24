import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/app_error_handling.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/app/theme/jejaku_theme.dart';
import 'package:jejaku/features/ar_viewer/hud/ar_hud_store.dart';
import 'package:jejaku/features/ar_viewer/services/ar_model_asset_cache_provider.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_export_bundle_store.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_store.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/auth/widgets/sign_in_gate.dart';
import 'package:jejaku/features/camera/services/ar_capture_diagnostics_cache_store.dart';
import 'package:jejaku/features/home/services/anchor_media_repository_bootstrap.dart';
import 'package:jejaku/features/home/services/anchor_memory_store.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/profile/services/user_profile_store.dart';
import 'package:jejaku/features/remote_frames/states/memory_api_provider.dart';
import 'package:jejaku/features/settings/services/app_settings_store.dart';
import 'package:jejaku/features/sync/services/anchor_media_upload_queue_store.dart';
import 'package:jejaku/features/sync/services/anchor_sync_delivery_log_store.dart';
import 'package:jejaku/features/trails/services/ar_trail_progress_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool _arOfflineTestMode =
    bool.fromEnvironment('JEZAKU_AR_TEST_MODE', defaultValue: false);

void main() {
  installGlobalErrorHandlers();
  _start();
}

Future<void> _start() async {
  try {
    await _bootstrapAndRun();
  } on Object catch (error, stackTrace) {
    appErrorBuffer.record(error, stackTrace, source: 'startup');
    runApp(const StartupFailureApp(onRetry: _start));
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
        persistentAppSettingsStoreOverride(
          preferences: preferences,
        ),
        persistentUserProfileStoreOverride(
          preferences: preferences,
        ),
        if (_identityUrl.isNotEmpty)
          httpAuthGatewayOverride(baseUrl: _identityUrl),
        if (_memoryUrl.isNotEmpty) memoryApiOverride(baseUrl: _memoryUrl),
        persistentARHudStoreOverride(
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

/// Base URL of the identity service, e.g. `http://10.0.2.2:8101`. Empty means
/// this build has no sign-in (the gate stays open).
const _identityUrl = String.fromEnvironment('JEZAKU_IDENTITY_URL');

/// Base URL of the memory service, e.g. `http://10.0.2.2:8104`. Empty means
/// this build does not load frames from a server.
const _memoryUrl = String.fromEnvironment('JEZAKU_MEMORY_URL');

class JejakuApp extends ConsumerWidget {
  const JejakuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(arModelAssetCacheStartupMaintenanceProvider);
    return MaterialApp(
      title: 'Jejaku',
      debugShowCheckedModeBanner: false,
      theme: JejakuTheme.light(),
      darkTheme: JejakuTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) =>
          SignInGate(child: child ?? const SizedBox.shrink()),
      initialRoute:
          _arOfflineTestMode ? AppRoutes.arViewer : AppRoutes.root,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
