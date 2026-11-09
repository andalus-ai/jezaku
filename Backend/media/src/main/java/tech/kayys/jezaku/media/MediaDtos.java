package tech.kayys.jezaku.media;

import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotApplyResponse;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchRequest;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public final class MediaDtos {
    private MediaDtos() {
    }

    public record UploadCreateRequest(
            String ownerId,
            String fileName,
            String contentType,
            long byteSize,
            String checksumSha256,
            String purpose,
            List<String> tags) {
    }

    public record UploadResponse(
            String uploadId,
            String ownerId,
            String fileName,
            String contentType,
            long byteSize,
            String checksumSha256,
            String purpose,
            List<String> tags,
            String uploadUrl,
            String mediaUrl,
            String status,
            String moderationStatus,
            Instant expiresAt,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record UploadCompleteRequest(String ownerId, Long byteSize, String checksumSha256) {
    }

    public record MediaResponse(
            String mediaId,
            String ownerId,
            String fileName,
            String contentType,
            long byteSize,
            String checksumSha256,
            String purpose,
            List<String> tags,
            String mediaUrl,
            String status,
            String moderationStatus,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record MediaReferenceResponse(
            String mediaId,
            String ownerId,
            String mediaUrl,
            String thumbnailUrl,
            String status,
            String moderationStatus,
            String purpose,
            String contentType,
            boolean memoryAttachable,
            boolean publicMemoryEligible,
            Instant updatedAt) {
    }

    public record MediaReferenceBatchRequest(List<String> mediaIds) {
    }

    public record MediaReferenceBatchResponse(
            int requestedCount,
            int resolvedCount,
            List<MediaReferenceResponse> references,
            List<String> missingMediaIds) {
    }

    public record MediaListResponse(String ownerId, int count, List<MediaResponse> media) {
    }

    public record MediaLifecycleEventResponse(
            long sequence,
            String eventId,
            String action,
            String mediaId,
            String ownerId,
            String mediaStatus,
            String moderationStatus,
            String purpose,
            String mediaUrl,
            boolean memoryAttachable,
            boolean publicMemoryEligible,
            Instant createdAt) {
    }

    public record MediaLifecycleEventsResponse(
            long afterSequence,
            long lastSequence,
            boolean hasMore,
            int count,
            List<MediaLifecycleEventResponse> events) {
    }

    public record MediaMemorySnapshotSyncResponse(
            long afterSequence,
            long lastSequence,
            boolean hasMore,
            int eventCount,
            int snapshotCount,
            String consumerId,
            long checkpointSequence,
            MemoryMediaSnapshotBatchRequest memoryRequest) {
    }

    public record MediaSyncCheckpointRequest(String consumerId, Long lastSequence) {
    }

    public record MediaSyncCheckpointResponse(
            String consumerId,
            long previousSequence,
            long lastSequence,
            boolean advanced,
            Instant updatedAt) {
    }

    public record MediaMemorySnapshotSyncRunRequest(
            String consumerId,
            Long afterSequence,
            Integer limit,
            String memoryBaseUrl) {
    }

    public record MediaMemorySnapshotSyncRetryRequest(
            String consumerId,
            Integer limit,
            String memoryBaseUrl,
            Boolean force) {
    }

    public record MediaMemorySnapshotSyncDispatchRequest(
            Integer limit,
            Integer maxRuns,
            String memoryBaseUrl) {
    }

    public record MediaMemorySnapshotSyncRunResponse(
            String runId,
            String consumerId,
            long afterSequence,
            long lastSequence,
            boolean hasMore,
            int eventCount,
            int snapshotCount,
            boolean memoryCalled,
            String outcome,
            String errorMessage,
            Instant startedAt,
            Instant completedAt,
            long durationMillis,
            MemoryMediaSnapshotApplyResponse<Map<String, Object>> memoryResponse,
            MediaSyncCheckpointResponse checkpoint) {
    }

    public record MediaMemorySnapshotSyncRunHistoryEntry(
            String runId,
            String consumerId,
            long afterSequence,
            long lastSequence,
            boolean hasMore,
            int eventCount,
            int snapshotCount,
            boolean memoryCalled,
            String outcome,
            String errorMessage,
            Instant startedAt,
            Instant completedAt,
            long durationMillis) {
    }

    public record MediaMemorySnapshotSyncRunHistorySummary(
            int succeededCount,
            int noopCount,
            int failedCount,
            int memoryCalledCount,
            int totalEventCount,
            int totalSnapshotCount,
            int consecutiveFailureCount,
            String latestRunId,
            String latestOutcome,
            String latestErrorMessage,
            Instant latestCompletedAt,
            Long latestDurationMillis,
            long totalDurationMillis,
            Long averageDurationMillis,
            Long maxDurationMillis,
            long slowThresholdMillis,
            int slowCount,
            boolean latestSlow,
            boolean maxSlow,
            String performanceHealth) {
    }

    public record MediaMemorySnapshotSyncRunHistoryResponse(
            String consumerId,
            int count,
            MediaMemorySnapshotSyncRunHistorySummary summary,
            List<MediaMemorySnapshotSyncRunHistoryEntry> runs) {
    }

    public record MediaMemorySnapshotSyncRunHint(
            boolean shouldRun,
            boolean retryable,
            String method,
            String path,
            String consumerId,
            long afterSequence,
            int limit) {
    }

    public record MediaMemorySnapshotSyncFailureSummary(
            boolean hasFailure,
            int consecutiveFailureCount,
            String severity,
            int nextRetryDelaySeconds,
            Instant nextRetryAt,
            boolean retryReady,
            boolean escalationRecommended,
            String lastFailedRunId,
            String lastErrorMessage,
            Instant lastFailedAt) {
    }

    public record MediaMemorySnapshotSyncActiveRun(
            boolean inProgress,
            String runId,
            Instant startedAt,
            Long runningSeconds,
            int expectedTimeoutSeconds,
            boolean overdue,
            String health,
            String recommendedAction) {
    }

    public record MediaMemorySnapshotSyncActiveDispatch(
            boolean inProgress,
            String dispatchId,
            Instant startedAt,
            Long runningSeconds,
            Integer maxRuns,
            String health,
            String recommendedAction) {
    }

    public record MediaMemorySnapshotSyncAttention(
            int priority,
            String level,
            String reason,
            String recommendedAction) {
    }

    public record MediaMemorySnapshotSyncStatusResponse(
            String consumerId,
            long checkpointSequence,
            long latestSequence,
            long sequenceLag,
            int pendingEventCount,
            int pendingSnapshotCount,
            boolean hasPendingSnapshots,
            String syncState,
            String recommendedAction,
            String statusReason,
            MediaMemorySnapshotSyncAttention attention,
            MediaMemorySnapshotSyncRunHint nextRun,
            MediaMemorySnapshotSyncActiveRun activeRun,
            MediaMemorySnapshotSyncFailureSummary failure,
            MediaMemorySnapshotSyncRunHistoryEntry lastRun,
            Instant checkedAt) {
    }

    public record MediaMemorySnapshotSyncStatusesSummary(
            int healthyCount,
            int pendingCount,
            int failedCount,
            int activeRunCount,
            int overdueRunCount,
            int retryReadyCount,
            int escalationRecommendedCount,
            int totalPendingEventCount,
            int totalPendingSnapshotCount,
            long totalSequenceLag) {
    }

    public record MediaMemorySnapshotSyncStatusesHeadline(
            String consumerId,
            int priority,
            String level,
            String reason,
            String recommendedAction) {
    }

    public record MediaMemorySnapshotSyncStatusesResponse(
            int count,
            int knownConsumerCount,
            boolean hasMore,
            Instant checkedAt,
            MediaMemorySnapshotSyncStatusesSummary summary,
            MediaMemorySnapshotSyncStatusesHeadline headline,
            MediaMemorySnapshotSyncRunHint recommendedRun,
            MediaMemorySnapshotSyncActiveDispatch activeDispatch,
            List<MediaMemorySnapshotSyncStatusResponse> statuses) {
    }

    public record MediaMemorySnapshotSyncOpsResponse(
            String opsHealth,
            String recommendedAction,
            Instant checkedAt,
            int statusCount,
            int knownConsumerCount,
            boolean hasMore,
            MediaMemorySnapshotSyncStatusesSummary summary,
            MediaMemorySnapshotSyncStatusesHeadline headline,
            MediaMemorySnapshotSyncRunHint recommendedRun,
            MediaMemorySnapshotSyncActiveDispatch activeDispatch,
            MediaMemorySnapshotSyncStatusResponse primaryStatus,
            MediaMemorySnapshotSyncRunHistoryResponse primaryRunHistory,
            MediaMemorySnapshotSyncDispatchHistoryResponse dispatchHistory,
            List<MediaMemorySnapshotSyncStatusResponse> statuses) {
    }

    public record MediaMemorySnapshotSyncDispatchResponse(
            String dispatchId,
            boolean dispatched,
            String skippedReason,
            String stoppedReason,
            MediaMemorySnapshotSyncStatusesHeadline headline,
            MediaMemorySnapshotSyncRunHint recommendedRun,
            MediaMemorySnapshotSyncRunResponse run,
            List<MediaMemorySnapshotSyncRunResponse> runs,
            int requestedRunCount,
            int runCount,
            MediaMemorySnapshotSyncActiveDispatch activeDispatch,
            Instant checkedAt,
            Instant completedAt,
            long durationMillis) {
    }

    public record MediaMemorySnapshotSyncDispatchHistoryEntry(
            String dispatchId,
            boolean dispatched,
            String skippedReason,
            String stoppedReason,
            String outcome,
            String recommendedConsumerId,
            String recommendedPath,
            Long recommendedAfterSequence,
            Integer recommendedLimit,
            String latestRunId,
            String latestConsumerId,
            String latestOutcome,
            String latestErrorMessage,
            int requestedRunCount,
            int runCount,
            Instant startedAt,
            Instant completedAt,
            long durationMillis) {
    }

    public record MediaMemorySnapshotSyncDispatchHistorySummary(
            int completedCount,
            int failedCount,
            int skippedCount,
            int dispatchInProgressSkippedCount,
            int noRunnableCount,
            int maxRunsReachedCount,
            int totalRunCount,
            String latestDispatchId,
            String latestOutcome,
            String latestStoppedReason,
            Instant latestCompletedAt,
            Long latestDurationMillis,
            long totalDurationMillis,
            Long averageDurationMillis,
            Long maxDurationMillis,
            long slowThresholdMillis,
            int slowCount,
            boolean latestSlow,
            boolean maxSlow,
            String performanceHealth) {
    }

    public record MediaMemorySnapshotSyncDispatchHistoryResponse(
            int count,
            MediaMemorySnapshotSyncDispatchHistorySummary summary,
            List<MediaMemorySnapshotSyncDispatchHistoryEntry> dispatches) {
    }

    public record ModerationUpdateRequest(String reviewerId, String moderationStatus, String reason) {
    }

    public record ModerationEventResponse(
            String eventId,
            String mediaId,
            String reviewerId,
            String moderationStatus,
            String previousStatus,
            String nextStatus,
            String reason,
            Instant createdAt) {
    }

    public record ModerationHistoryResponse(String mediaId, int count, List<ModerationEventResponse> events) {
    }
}
