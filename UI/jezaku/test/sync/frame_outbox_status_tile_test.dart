import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/sync/widgets/frame_outbox_status_tile.dart';
import 'package:material_ui/material_ui.dart';

import 'outbox_test_rig.dart';

Widget _host(ProviderContainer container, String memoryId) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: FrameOutboxStatusTile(memoryId: memoryId)),
    ),
  );
}

void main() {
  testWidgets('draws nothing for a frame that is not waiting', (tester) async {
    final container = outboxContainer(publisher: OutboxTestPublisher());
    await tester.pumpWidget(_host(container, 'unknown'));

    expect(
      find.descendant(
        of: find.byType(FrameOutboxStatusTile),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
    expect(find.text('Send now'), findsNothing);
  });

  testWidgets('offline frame explains itself and can be sent now',
      (tester) async {
    final publisher = OutboxTestPublisher()
      ..createError = const ApiFailure(ApiFailureReason.network);
    final container = outboxContainer(publisher: publisher);
    final memory = captureFrame(container);
    await tester.runAsync(() => settleOutbox(container));

    await tester.pumpWidget(_host(container, memory.id));

    expect(find.text('Waiting for a connection'), findsOneWidget);
    expect(find.textContaining('automatically'), findsOneWidget);
    expect(find.text('Send now'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Stop sending'), findsOneWidget);

    publisher.createError = null;
    await tester.tap(find.text('Send now'));
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(publisher.created, [memory.id]);
    expect(find.text('Waiting for a connection'), findsNothing);
  });

  testWidgets('a refused frame offers try again and stop sending',
      (tester) async {
    final publisher = OutboxTestPublisher()
      ..createError = const ApiFailure(
        ApiFailureReason.server,
        statusCode: 400,
      );
    final container = outboxContainer(publisher: publisher);
    final memory = captureFrame(container);
    await tester.runAsync(() => settleOutbox(container));

    await tester.pumpWidget(_host(container, memory.id));

    expect(find.text('The service refused this frame'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Send now'), findsNothing);

    await tester.tap(find.text('Stop sending'));
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(find.text('The service refused this frame'), findsNothing);
  });
}
