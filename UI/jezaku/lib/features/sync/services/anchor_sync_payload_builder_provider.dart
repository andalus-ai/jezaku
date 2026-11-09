import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/sync/models/anchor_sync_payload.dart';
import 'package:jejaku/features/sync/services/local_first_sync_runtime.dart';

final anchorSyncPayloadBuilderProvider =
    Provider<AnchorSyncPayloadBuilder>((ref) {
  return AnchorSyncPayloadBuilder(
    runtime: ref.watch(localFirstSyncRuntimeProvider),
  );
});
