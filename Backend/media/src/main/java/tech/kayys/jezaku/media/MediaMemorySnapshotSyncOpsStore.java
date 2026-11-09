package tech.kayys.jezaku.media;

import java.util.List;

public interface MediaMemorySnapshotSyncOpsStore {
    MediaSyncCheckpointRecord saveSyncCheckpoint(MediaSyncCheckpointRecord checkpoint);

    MediaSyncCheckpointRecord findSyncCheckpoint(String consumerId);

    List<String> findMemorySnapshotSyncConsumerIds();

    MediaMemorySnapshotSyncRunRecord saveMemorySnapshotSyncRun(MediaMemorySnapshotSyncRunRecord run);

    List<MediaMemorySnapshotSyncRunRecord> findMemorySnapshotSyncRuns(String consumerId, int limit);

    MediaMemorySnapshotSyncDispatchRecord saveMemorySnapshotSyncDispatch(
            MediaMemorySnapshotSyncDispatchRecord dispatch);

    List<MediaMemorySnapshotSyncDispatchRecord> findMemorySnapshotSyncDispatches(int limit);
}
