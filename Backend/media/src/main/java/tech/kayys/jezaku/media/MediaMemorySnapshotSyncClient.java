package tech.kayys.jezaku.media;

import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotApplyResponse;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchRequest;

import java.util.Map;

interface MediaMemorySnapshotSyncClient {
    MemoryMediaSnapshotApplyResponse<Map<String, Object>> apply(
            String memoryBaseUrlOverride,
            MemoryMediaSnapshotBatchRequest request);
}
