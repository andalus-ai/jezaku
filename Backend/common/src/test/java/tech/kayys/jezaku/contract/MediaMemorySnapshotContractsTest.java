package tech.kayys.jezaku.contract;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotApplyResponse;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchItem;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchRequest;

import java.lang.reflect.RecordComponent;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class MediaMemorySnapshotContractsTest {
    @Test
    void keepsMediaToMemorySnapshotWireFieldNamesStable() {
        assertEquals(
                List.of("mediaId", "mediaStatus", "moderationStatus", "sequence", "eventId", "action"),
                recordComponentNames(MemoryMediaSnapshotBatchItem.class));
        assertEquals(
                List.of("snapshots"),
                recordComponentNames(MemoryMediaSnapshotBatchRequest.class));
        assertEquals(
                List.of(
                        "requestedCount",
                        "appliedCount",
                        "staleCount",
                        "totalUpdatedCount",
                        "lastAppliedSequence",
                        "unmatchedMediaIds",
                        "staleMediaIds",
                        "results"),
                recordComponentNames(MemoryMediaSnapshotApplyResponse.class));
    }

    private List<String> recordComponentNames(Class<? extends Record> recordType) {
        return Arrays.stream(recordType.getRecordComponents())
                .map(RecordComponent::getName)
                .toList();
    }
}
