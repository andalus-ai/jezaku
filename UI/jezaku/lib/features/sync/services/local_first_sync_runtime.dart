import 'package:flutter_riverpod/flutter_riverpod.dart';

final localFirstSyncRuntimeProvider = Provider<LocalFirstSyncRuntime>((ref) {
  return const LocalFirstSyncRuntime.fromEnvironment();
});

class LocalFirstSyncRuntime {
  const LocalFirstSyncRuntime({
    required this.offlineMode,
    required this.useDummyData,
    required this.profileMode,
    required this.apiBaseUrl,
    required this.backendHost,
    required this.tenantRealm,
  });

  const LocalFirstSyncRuntime.fromEnvironment()
      : offlineMode = const bool.fromEnvironment('OFFLINE_MODE'),
        useDummyData = const bool.fromEnvironment('USE_DUMMY_DATA'),
        profileMode = const String.fromEnvironment(
          'PROFILE_MODE',
          defaultValue: 'default',
        ),
        apiBaseUrl = const String.fromEnvironment('API_BASE_URL'),
        backendHost = const String.fromEnvironment('BACKEND_HOST'),
        tenantRealm = const String.fromEnvironment(
          'TENANT_REALM',
          defaultValue: 'jezaku',
        );

  final bool offlineMode;
  final bool useDummyData;
  final String profileMode;
  final String apiBaseUrl;
  final String backendHost;
  final String tenantRealm;

  bool get canFlushToServer => !offlineMode;

  String get modeLabel {
    if (offlineMode) {
      return 'Device-only demo mode';
    }
    if (useDummyData || profileMode == 'demo') {
      return 'Demo sync ready';
    }
    return 'Server sync ready';
  }

  String get endpointLabel {
    final apiBase = apiBaseUrl.trim();
    if (apiBase.isNotEmpty) {
      return apiBase;
    }
    final host = backendHost.trim();
    if (host.isNotEmpty) {
      return host;
    }
    return 'configured backend';
  }

  String queueMessage(int pendingCount) {
    final itemLabel = pendingCount == 1 ? 'sync item' : 'sync items';
    if (!canFlushToServer) {
      return '$pendingCount $itemLabel saved locally for $tenantRealm.';
    }
    return '$pendingCount $itemLabel ready for $endpointLabel.';
  }

  String blockedSyncMessage(int itemCount) {
    final itemLabel = itemCount == 1 ? 'sync item' : 'sync items';
    final verb = itemCount == 1 ? 'stays' : 'stay';
    return 'Device-only demo mode: $itemCount $itemLabel $verb saved on this device.';
  }

  String get offlineMediaErrorLabel {
    return 'Device-only demo mode; media stays saved locally.';
  }
}
