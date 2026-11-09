package tech.kayys.jezaku.media;

import jakarta.enterprise.context.ApplicationScoped;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicLong;

@ApplicationScoped
public class InMemoryMediaRepository implements MediaRepository, MediaMemorySnapshotSyncOpsStore {
    private final Map<String, UploadRecord> uploads = new ConcurrentHashMap<>();
    private final Map<String, MediaRecord> media = new ConcurrentHashMap<>();
    private final Map<String, List<MediaModerationEvent>> moderationEvents = new ConcurrentHashMap<>();
    private final Map<String, MediaSyncCheckpointRecord> syncCheckpoints = new ConcurrentHashMap<>();
    private final CopyOnWriteArrayList<MediaMemorySnapshotSyncRunRecord> memorySnapshotSyncRuns =
            new CopyOnWriteArrayList<>();
    private final CopyOnWriteArrayList<MediaMemorySnapshotSyncDispatchRecord> memorySnapshotSyncDispatches =
            new CopyOnWriteArrayList<>();
    private final CopyOnWriteArrayList<MediaLifecycleEventRecord> lifecycleEvents = new CopyOnWriteArrayList<>();
    private final AtomicLong lifecycleSequence = new AtomicLong();

    @Override
    public void saveUpload(UploadRecord upload) {
        uploads.put(upload.uploadId(), upload);
    }

    @Override
    public UploadRecord findUploadById(String uploadId) {
        return uploads.get(uploadId);
    }

    @Override
    public void saveMedia(MediaRecord record) {
        media.put(record.mediaId(), record);
    }

    @Override
    public MediaRecord findMediaById(String mediaId) {
        return media.get(mediaId);
    }

    @Override
    public List<MediaRecord> findAllMedia() {
        return List.copyOf(media.values());
    }

    @Override
    public void saveModerationEvent(MediaModerationEvent event) {
        moderationEvents.compute(event.mediaId(), (mediaId, events) -> {
            List<MediaModerationEvent> updated = new ArrayList<>();
            if (events != null) {
                updated.addAll(events);
            }
            updated.add(event);
            return List.copyOf(updated);
        });
    }

    @Override
    public List<MediaModerationEvent> findModerationEventsByMediaId(String mediaId) {
        return List.copyOf(moderationEvents.getOrDefault(mediaId, List.of()));
    }

    @Override
    public MediaLifecycleEventRecord saveLifecycleEvent(MediaLifecycleEventRecord event) {
        lifecycleEvents.add(event);
        return event;
    }

    @Override
    public long nextLifecycleSequence() {
        return lifecycleSequence.incrementAndGet();
    }

    @Override
    public long latestLifecycleSequence() {
        return lifecycleSequence.get();
    }

    @Override
    public List<MediaLifecycleEventRecord> findLifecycleEventsAfter(long sequence, int limit) {
        return lifecycleEvents.stream()
                .filter(event -> event.sequence() > sequence)
                .sorted(java.util.Comparator.comparingLong(MediaLifecycleEventRecord::sequence))
                .limit(limit)
                .toList();
    }

    @Override
    public MediaSyncCheckpointRecord saveSyncCheckpoint(MediaSyncCheckpointRecord checkpoint) {
        syncCheckpoints.put(checkpoint.consumerId(), checkpoint);
        return checkpoint;
    }

    @Override
    public MediaSyncCheckpointRecord findSyncCheckpoint(String consumerId) {
        return syncCheckpoints.get(consumerId);
    }

    @Override
    public List<String> findMemorySnapshotSyncConsumerIds() {
        TreeSet<String> consumerIds = new TreeSet<>(syncCheckpoints.keySet());
        memorySnapshotSyncRuns.stream()
                .map(MediaMemorySnapshotSyncRunRecord::consumerId)
                .forEach(consumerIds::add);
        return List.copyOf(consumerIds);
    }

    @Override
    public MediaMemorySnapshotSyncRunRecord saveMemorySnapshotSyncRun(MediaMemorySnapshotSyncRunRecord run) {
        memorySnapshotSyncRuns.add(run);
        return run;
    }

    @Override
    public List<MediaMemorySnapshotSyncRunRecord> findMemorySnapshotSyncRuns(String consumerId, int limit) {
        return memorySnapshotSyncRuns.stream()
                .filter(run -> consumerId == null || run.consumerId().equals(consumerId))
                .sorted(java.util.Comparator.comparing(MediaMemorySnapshotSyncRunRecord::startedAt).reversed())
                .limit(limit)
                .toList();
    }

    @Override
    public MediaMemorySnapshotSyncDispatchRecord saveMemorySnapshotSyncDispatch(
            MediaMemorySnapshotSyncDispatchRecord dispatch) {
        memorySnapshotSyncDispatches.add(dispatch);
        return dispatch;
    }

    @Override
    public List<MediaMemorySnapshotSyncDispatchRecord> findMemorySnapshotSyncDispatches(int limit) {
        return memorySnapshotSyncDispatches.stream()
                .sorted(java.util.Comparator.comparing(MediaMemorySnapshotSyncDispatchRecord::startedAt).reversed())
                .limit(limit)
                .toList();
    }
}
