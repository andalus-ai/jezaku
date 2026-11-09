package tech.kayys.jezaku.messaging;

import java.time.Instant;
import java.util.Map;

record MessagingOpsAuditEvent(
        String auditId,
        String action,
        String actor,
        String requestId,
        String outcome,
        Map<String, Object> details,
        Instant occurredAt) {
    MessagingOpsAuditEvent {
        details = details == null ? Map.of() : Map.copyOf(details);
    }
}
