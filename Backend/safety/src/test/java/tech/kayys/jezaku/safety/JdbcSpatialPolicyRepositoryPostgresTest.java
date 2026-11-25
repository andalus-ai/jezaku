package tech.kayys.jezaku.safety;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import jakarta.inject.Inject;

import org.junit.jupiter.api.Test;

import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;

/**
 * Exercises JDBC persistence, Flyway startup and transaction-scoped locking
 * against a real PostgreSQL instance rather than the in-memory test adapter.
 */
@QuarkusTest
@QuarkusTestResource(PostgresSpatialPolicyTestResource.class)
class JdbcSpatialPolicyRepositoryPostgresTest {

    @Inject
    JdbcSpatialPolicyRepository repository;

    @Test
    void concurrentFirstProvisioningProducesOneCreatedAndOneUpdatedAuditEvent() throws Exception {
        String principalId = "postgres-test-" + UUID.randomUUID();
        AuthorityPrincipal principal = new AuthorityPrincipal(
                principalId,
                "GOVERNMENT",
                AuthorityPrincipal.Status.VERIFIED,
                List.of(new AuthorityPrincipal.JurisdictionScope("ID.JB.BDG", true)),
                Set.of(AuthorityPrincipal.Permission.CREATE_RESTRICTION),
                Instant.now().minusSeconds(60),
                null);

        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        try (ExecutorService executor = Executors.newFixedThreadPool(2)) {
            Future<?> first = executor.submit(() -> saveWhenReleased(principal, ready, start, "test-actor-a"));
            Future<?> second = executor.submit(() -> saveWhenReleased(principal, ready, start, "test-actor-b"));

            assertTrue(ready.await(10, TimeUnit.SECONDS), "both provisioning workers should be ready");
            start.countDown();
            first.get(30, TimeUnit.SECONDS);
            second.get(30, TimeUnit.SECONDS);
        }

        List<AuthorityAuditEvent> history = repository.findAuthorityAuditHistory(principalId);
        assertEquals(2, history.size(), "both successful writes must be audited");
        assertEquals(1, history.stream().filter(event -> "CREATED".equals(event.action())).count());
        assertEquals(1, history.stream().filter(event -> "UPDATED".equals(event.action())).count());
        assertEquals("UPDATED", history.get(0).action(), "history is returned newest first");
        assertEquals("CREATED", history.get(1).action());
        assertTrue(repository.findAuthority(principalId).isPresent());
    }

    private void saveWhenReleased(AuthorityPrincipal principal, CountDownLatch ready,
            CountDownLatch start, String actorId) {
        ready.countDown();
        try {
            if (!start.await(10, TimeUnit.SECONDS)) {
                throw new IllegalStateException("timed out waiting for concurrent start");
            }
            repository.saveAuthority(principal, actorId);
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("interrupted while coordinating concurrent provisioning", interrupted);
        }
    }
}
