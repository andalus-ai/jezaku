package tech.kayys.jezaku.presence;

import java.util.List;

record PresenceAudienceAccessRequest(String viewerId, List<PresenceAudienceOwner> owners) {
    PresenceAudienceAccessRequest {
        viewerId = viewerId == null ? "" : viewerId.trim();
        owners = owners == null ? List.of() : List.copyOf(owners);
    }

    static PresenceAudienceAccessRequest from(String viewerId, List<PresenceRecord> records) {
        List<PresenceAudienceOwner> owners = records == null
                ? List.of()
                : records.stream()
                        .map(record -> new PresenceAudienceOwner(record.userId(), record.visibility()))
                        .distinct()
                        .toList();
        return new PresenceAudienceAccessRequest(viewerId, owners);
    }
}

record PresenceAudienceOwner(String ownerId, String visibility) {
    PresenceAudienceOwner {
        ownerId = ownerId == null ? "" : ownerId.trim();
        visibility = visibility == null || visibility.isBlank() ? "public" : visibility.trim();
    }
}

record PresenceAudienceAccessResponse(
        String viewerId,
        String source,
        boolean fallback,
        List<PresenceAudienceAccessDecision> decisions) {
    PresenceAudienceAccessResponse(String viewerId, List<PresenceAudienceAccessDecision> decisions) {
        this(viewerId, "local", false, decisions);
    }

    PresenceAudienceAccessResponse {
        viewerId = viewerId == null ? "" : viewerId.trim();
        source = source == null || source.isBlank() ? "local" : source.trim();
        decisions = decisions == null ? List.of() : List.copyOf(decisions);
    }

    PresenceAudienceAccessResponse withSource(String source, boolean fallback) {
        return new PresenceAudienceAccessResponse(viewerId, source, fallback, decisions);
    }

    PresenceAudienceAccessDecision decisionFor(PresenceRecord record) {
        return decisions.stream()
                .filter(decision -> decision.ownerId().equals(record.userId()))
                .findFirst()
                .orElseGet(() -> PresenceAudienceAccessDecision.deny(
                        record.userId(),
                        PresenceVisibilityPolicy.REASON_VISIBILITY_HIDDEN));
    }
}

record PresenceAudienceAccessDecision(String ownerId, boolean canView, String reason) {
    PresenceAudienceAccessDecision {
        ownerId = ownerId == null ? "" : ownerId.trim();
        reason = reason == null || reason.isBlank()
                ? PresenceVisibilityPolicy.REASON_VISIBILITY_HIDDEN
                : reason.trim();
    }

    static PresenceAudienceAccessDecision allow(String ownerId, String reason) {
        return new PresenceAudienceAccessDecision(ownerId, true, reason);
    }

    static PresenceAudienceAccessDecision deny(String ownerId, String reason) {
        return new PresenceAudienceAccessDecision(ownerId, false, reason);
    }
}
