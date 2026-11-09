package tech.kayys.jezaku.memory;

import java.util.List;

public interface MemoryRepository {
    void save(MemoryRecord memory);

    MemoryRecord findById(String id);

    List<MemoryRecord> findAll();

    void saveAnchorHistory(MemoryAnchorHistoryRecord event);

    List<MemoryAnchorHistoryRecord> anchorHistory(String memoryId);

    MemoryMediaSnapshotProgressRecord saveMediaSnapshotProgress(MemoryMediaSnapshotProgressRecord progress);

    MemoryMediaSnapshotProgressRecord findMediaSnapshotProgress(String mediaId);

    boolean deleteById(String id);
}
