package tech.kayys.jezaku.media;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotApplyResponse;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchItem;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchRequest;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class HttpMediaMemorySnapshotSyncClientTest {
    @Test
    void postsMemorySnapshotBatchToConfiguredMemoryEndpoint() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>();
        HttpServer server = server(200, requestBody);
        try {
            server.start();
            HttpMediaMemorySnapshotSyncClient client = client(server);

            MemoryMediaSnapshotApplyResponse<Map<String, Object>> response = client.apply(null, request());

            Map<?, ?> body = new ObjectMapper().readValue(requestBody.get(), Map.class);
            assertEquals("media_sync_client", ((Map<?, ?>) ((List<?>) body.get("snapshots")).getFirst()).get("mediaId"));
            assertEquals(1, response.requestedCount());
            assertEquals(1, response.appliedCount());
            assertEquals(9L, response.lastAppliedSequence());
        } finally {
            server.stop(0);
        }
    }

    @Test
    void failsWhenMemoryEndpointReturnsNonSuccessStatus() throws Exception {
        HttpServer server = server(503, new AtomicReference<>());
        try {
            server.start();
            HttpMediaMemorySnapshotSyncClient client = client(server);

            IllegalStateException exception = assertThrows(
                    IllegalStateException.class,
                    () -> client.apply(null, request()));

            assertEquals("Memory snapshot sync failed with status 503", exception.getMessage());
        } finally {
            server.stop(0);
        }
    }

    @Test
    void usesConfiguredRequestTimeoutWithDefaultFallback() {
        HttpMediaMemorySnapshotSyncClient client = new HttpMediaMemorySnapshotSyncClient();

        client.requestTimeoutSeconds = 2;
        assertEquals(Duration.ofSeconds(2), client.requestTimeout());

        client.requestTimeoutSeconds = 0;
        assertEquals(Duration.ofSeconds(5), client.requestTimeout());
    }

    private HttpServer server(int status, AtomicReference<String> requestBody) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("localhost", 0), 0);
        server.createContext("/memories/media/snapshots", exchange -> {
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] response = """
                    {
                      "requestedCount": 1,
                      "appliedCount": 1,
                      "staleCount": 0,
                      "totalUpdatedCount": 1,
                      "lastAppliedSequence": 9,
                      "unmatchedMediaIds": [],
                      "staleMediaIds": [],
                      "results": []
                    }
                    """.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status, response.length);
            exchange.getResponseBody().write(response);
            exchange.close();
        });
        return server;
    }

    private HttpMediaMemorySnapshotSyncClient client(HttpServer server) {
        HttpMediaMemorySnapshotSyncClient client = new HttpMediaMemorySnapshotSyncClient();
        client.objectMapper = new ObjectMapper();
        client.memoryBaseUrl = Optional.of("http://localhost:%d".formatted(server.getAddress().getPort()));
        return client;
    }

    private MemoryMediaSnapshotBatchRequest request() {
        return new MemoryMediaSnapshotBatchRequest(List.of(new MemoryMediaSnapshotBatchItem(
                "media_sync_client",
                "active",
                "approved",
                9L,
                "media_event_sync_client",
                "moderated")));
    }
}
