import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/home/states/sample_data_provider.dart';
import 'package:jejaku/features/sync/outbox/frame_deletion_syncer.dart';
import 'package:jejaku/features/sync/outbox/pending_deletion_store.dart';
import 'package:jejaku/features/sync/screens/sync_queue_screen.dart';
import 'package:jejaku/features/sync/states/frame_outbox_providers.dart';
import 'package:jejaku/features/sync/widgets/pending_deletions_notice.dart';
import 'package:material_ui/material_ui.dart';

class _Api implements FrameDeletionApi {
  Object? error;
  final calls = <String>[];

  @override
  Future<void> deleteFrame({required String serverMemoryId}) async {
    calls.add(serverMemoryId);
    if (error != null) {
      throw error!;
    }
  }
}

PendingDeletionStore _storeWith(int count) {
  final store = InMemoryPendingDeletionStore();
  store.save([
    for (var i = 0; i < count; i++)
      PendingDeletion(
        serverMemoryId: 'srv-$i',
        ownerId: 'u-1',
        deletedAt: DateTime.utc(2026, 11, 28),
      ),
  ]);
  return store;
}

ProviderContainer _container(_Api api, PendingDeletionStore store) {
  final container = ProviderContainer(
    overrides: [
      sampleDataEnabledProvider.overrideWithValue(false),
      signedInUserIdProvider.overrideWithValue('u-1'),
      pendingDeletionStoreProvider.overrideWithValue(store),
      frameDeletionSyncerProvider.overrideWith(
        (ref) => FrameDeletionSyncer(
          api: api,
          store: store,
          onChanged: (count) =>
              ref.read(pendingDeletionCountProvider.notifier).set(count),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _host(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: child),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    ),
  );
}

void main() {
  testWidgets('draws nothing when no deletion is waiting', (tester) async {
    final container = _container(_Api(), _storeWith(0));

    await tester.pumpWidget(_host(container, const PendingDeletionsNotice()));

    expect(find.byKey(const ValueKey('pending_deletions_notice')), findsNothing);
    expect(find.text('Try now'), findsNothing);
  });

  testWidgets('says how many deleted frames the server still has',
      (tester) async {
    final one = _container(_Api(), _storeWith(1));
    await tester.pumpWidget(_host(one, const PendingDeletionsNotice()));
    expect(
      find.text('1 deleted frame is still to be removed from the server'),
      findsOneWidget,
    );
    expect(find.textContaining('already gone from this device'), findsOneWidget);

    final two = _container(_Api(), _storeWith(2));
    await tester.pumpWidget(_host(two, const PendingDeletionsNotice()));
    expect(
      find.text('2 deleted frames are still to be removed from the server'),
      findsOneWidget,
    );
  });

  testWidgets('Try now removes them and the notice goes away', (tester) async {
    final api = _Api();
    final container = _container(api, _storeWith(2));
    await tester.pumpWidget(_host(container, const PendingDeletionsNotice()));

    await tester.tap(find.text('Try now'));
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(api.calls, ['srv-0', 'srv-1']);
    expect(find.byKey(const ValueKey('pending_deletions_notice')), findsNothing);
    expect(find.text('2 deleted frames removed from the server.'), findsOneWidget);
  });

  testWidgets('offline Try now keeps the notice and says why', (tester) async {
    final api = _Api()..error = const ApiFailure(ApiFailureReason.network);
    final container = _container(api, _storeWith(1));
    await tester.pumpWidget(_host(container, const PendingDeletionsNotice()));

    await tester.tap(find.text('Try now'));
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(find.byKey(const ValueKey('pending_deletions_notice')), findsOneWidget);
    expect(find.textContaining('Could not reach the server'), findsOneWidget);
    // Back to a button that can be pressed again.
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('pending_deletions_try_now')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('the sync queue shows it even when nothing else is waiting',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = _container(_Api(), _storeWith(1));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SyncQueueScreen(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pending_deletions_notice')), findsOneWidget);
  });
}
