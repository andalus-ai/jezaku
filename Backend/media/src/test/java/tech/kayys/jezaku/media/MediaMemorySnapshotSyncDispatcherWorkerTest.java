package tech.kayys.jezaku.media;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncDispatchRequest;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;

class MediaMemorySnapshotSyncDispatcherWorkerTest {
    @Test
    void staysIdleWhenDisabled() {
        MediaMemorySnapshotSyncDispatcherWorker worker =
                new MediaMemorySnapshotSyncDispatcherWorker(null, null, false, 30, 1, 50, (String) null);

        assertFalse(worker.enabled());
        assertFalse(worker.runScheduledDispatch());
        assertFalse(worker.dispatchInProgress());
        assertNull(worker.latestDispatch());
    }

    @Test
    void buildsBoundedDispatchRequestFromConfig() {
        MediaMemorySnapshotSyncDispatcherWorker worker =
                new MediaMemorySnapshotSyncDispatcherWorker(null, null, true, 0, 500, 500, " http://memory.local ");

        MediaMemorySnapshotSyncDispatchRequest request = worker.scheduledDispatchRequest();

        assertEquals(30, worker.intervalSeconds());
        assertEquals(100, request.limit());
        assertEquals(10, request.maxRuns());
        assertEquals("http://memory.local", request.memoryBaseUrl());
    }

    @Test
    void omitsBlankMemoryBaseUrl() {
        MediaMemorySnapshotSyncDispatcherWorker worker =
                new MediaMemorySnapshotSyncDispatcherWorker(null, null, true, 15, 2, 25, "   ");

        MediaMemorySnapshotSyncDispatchRequest request = worker.scheduledDispatchRequest();

        assertEquals(15, worker.intervalSeconds());
        assertEquals(25, request.limit());
        assertEquals(2, request.maxRuns());
        assertNull(request.memoryBaseUrl());
    }
}
