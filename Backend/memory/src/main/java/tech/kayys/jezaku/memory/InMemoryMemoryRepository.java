package tech.kayys.jezaku.memory;

import jakarta.enterprise.context.ApplicationScoped;

import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.ConcurrentHashMap;

@ApplicationScoped
public class InMemoryMemoryRepository implements MemoryRepository {
    private final Map<String, MemoryRecord> memories = new ConcurrentHashMap<>();
    private final Map<String, CopyOnWriteArrayList<MemoryAnchorHistoryRecord>> anchorHistory =
            new ConcurrentHashMap<>();
    private final Map<String, MemoryMediaSnapshotProgressRecord> mediaSnapshotProgress = new ConcurrentHashMap<>();

    @Override
    public void save(MemoryRecord memory) {
        memories.put(memory.id(), memory);
    }

    @Override
    public MemoryRecord findById(String id) {
        return memories.get(id);
    }

    @Override
    public List<MemoryRecord> findAll() {
        return List.copyOf(memories.values());
    }

    @Override
    public void saveAnchorHistory(MemoryAnchorHistoryRecord event) {
        anchorHistory.computeIfAbsent(event.memoryId(), ignored -> new CopyOnWriteArrayList<>())
                .add(event);
    }

    @Override
    public List<MemoryAnchorHistoryRecord> anchorHistory(String memoryId) {
        return anchorHistory.getOrDefault(memoryId, new CopyOnWriteArrayList<>()).stream()
                .sorted(Comparator.comparingInt(MemoryAnchorHistoryRecord::revision))
                .toList();
    }

    @Override
    public MemoryMediaSnapshotProgressRecord saveMediaSnapshotProgress(MemoryMediaSnapshotProgressRecord progress) {
        mediaSnapshotProgress.put(progress.mediaId(), progress);
        return progress;
    }

    @Override
    public MemoryMediaSnapshotProgressRecord findMediaSnapshotProgress(String mediaId) {
        return mediaSnapshotProgress.get(mediaId);
    }

    @Override
    public boolean deleteById(String id) {
        boolean removed = memories.remove(id) != null;
        if (removed) {
            anchorHistory.remove(id);
        }
        return removed;
    }
}
