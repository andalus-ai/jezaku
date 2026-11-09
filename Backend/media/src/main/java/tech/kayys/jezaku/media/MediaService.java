package tech.kayys.jezaku.media;

import io.smallrye.mutiny.Uni;
import io.smallrye.mutiny.infrastructure.Infrastructure;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.BadRequestException;
import jakarta.ws.rs.ForbiddenException;
import jakarta.ws.rs.NotFoundException;
import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotApplyResponse;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchItem;
import tech.kayys.jezaku.contract.MediaMemorySnapshotContracts.MemoryMediaSnapshotBatchRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaLifecycleEventResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaLifecycleEventsResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaListResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncActiveDispatch;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncActiveRun;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncAttention;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncDispatchHistoryEntry;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncDispatchHistoryResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncDispatchHistorySummary;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncDispatchRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncDispatchResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncFailureSummary;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncOpsResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncRunHint;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncRunHistoryEntry;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncRunHistoryResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncRunHistorySummary;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncRunRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncRunResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncRetryRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncStatusResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncStatusesHeadline;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncStatusesResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaMemorySnapshotSyncStatusesSummary;
import tech.kayys.jezaku.media.MediaDtos.MediaReferenceBatchRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaReferenceBatchResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaReferenceResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaResponse;
import tech.kayys.jezaku.media.MediaDtos.MediaSyncCheckpointRequest;
import tech.kayys.jezaku.media.MediaDtos.MediaSyncCheckpointResponse;
import tech.kayys.jezaku.media.MediaDtos.ModerationEventResponse;
import tech.kayys.jezaku.media.MediaDtos.ModerationHistoryResponse;
import tech.kayys.jezaku.media.MediaDtos.ModerationUpdateRequest;
import tech.kayys.jezaku.media.MediaDtos.UploadCompleteRequest;
import tech.kayys.jezaku.media.MediaDtos.UploadCreateRequest;
import tech.kayys.jezaku.media.MediaDtos.UploadResponse;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicReference;

import static tech.kayys.jezaku.taxonomy.JezakuWorkflowChoices.MEDIA_MODERATION_STATUSES;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedInt;
import static tech.kayys.jezaku.validation.RequestParams.normalizeBoundedLong;
import static tech.kayys.jezaku.validation.TextParams.normalizeUniqueStrings;
import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;

@ApplicationScoped
public class MediaService {
    private static final long MAX_UPLOAD_BYTES = 100L * 1024L * 1024L;
    private static final Duration UPLOAD_TTL = Duration.ofMinutes(15);
    private static final String STATUS_ACTIVE = "active";
    private static final String STATUS_DELETED = "deleted";
    private static final String STATUS_REJECTED = "rejected";
    private static final String MODERATION_APPROVED = "approved";
    private static final String MODERATION_REJECTED = "rejected";
    private static final int MAX_MODERATION_REASON_LENGTH = 500;
    private static final int MAX_REFERENCE_BATCH_SIZE = 100;
    private static final int DEFAULT_EVENT_LIMIT = 50;
    private static final int MAX_EVENT_LIMIT = 100;
    private static final int DEFAULT_SYNC_RUN_HISTORY_LIMIT = 20;
    private static final int MAX_SYNC_RUN_HISTORY_LIMIT = 100;
    private static final int DEFAULT_SYNC_DISPATCH_HISTORY_LIMIT = 20;
    private static final int MAX_SYNC_DISPATCH_HISTORY_LIMIT = 100;
    private static final int DEFAULT_SYNC_STATUS_LIMIT = 20;
    private static final int MAX_SYNC_STATUS_LIMIT = 100;
    private static final int DEFAULT_SYNC_OPS_HISTORY_LIMIT = 5;
    private static final int MAX_SYNC_OPS_HISTORY_LIMIT = 100;
    private static final int DEFAULT_SYNC_DISPATCH_RUN_LIMIT = 1;
    private static final int MAX_SYNC_DISPATCH_RUN_LIMIT = 10;
    private static final int SYNC_FAILURE_ESCALATION_COUNT = 3;
    private static final int SYNC_FAILURE_FIRST_RETRY_DELAY_SECONDS = 30;
    private static final int SYNC_FAILURE_SECOND_RETRY_DELAY_SECONDS = 60;
    private static final int SYNC_FAILURE_ESCALATED_RETRY_DELAY_SECONDS = 300;
    private static final int MAX_CONSUMER_ID_LENGTH = 80;
    private static final int DEFAULT_MEMORY_SYNC_TIMEOUT_SECONDS = 5;
    private static final String DEFAULT_MEMORY_SYNC_CONSUMER_ID = "memory-snapshots";
    private static final String SYNC_OUTCOME_FAILED = "failed";
    private static final String SYNC_OUTCOME_NOOP = "noop";
    private static final String SYNC_OUTCOME_SUCCEEDED = "succeeded";
    private static final String SYNC_STATE_FAILED = "failed";
    private static final String SYNC_STATE_HEALTHY = "healthy";
    private static final String SYNC_STATE_PENDING = "pending";
    private static final String SYNC_ACTION_INSPECT_LAST_RUN = "inspect_last_run";
    private static final String SYNC_ACTION_NONE = "none";
    private static final String SYNC_ACTION_RETRY = "retry_sync";
    private static final String SYNC_ACTION_RUN = "run_sync";
    private static final String ACTIVE_RUN_ACTION_INSPECT_MEMORY = "inspect_memory_service";
    private static final String ACTIVE_RUN_ACTION_NONE = "none";
    private static final String ACTIVE_RUN_ACTION_WAIT = "wait";
    private static final String ACTIVE_DISPATCH_ACTION_NONE = "none";
    private static final String ACTIVE_DISPATCH_ACTION_WAIT = "wait";
    private static final String ACTIVE_DISPATCH_HEALTH_IDLE = "idle";
    private static final String ACTIVE_DISPATCH_HEALTH_RUNNING = "running";
    private static final String ACTIVE_RUN_HEALTH_IDLE = "idle";
    private static final String ACTIVE_RUN_HEALTH_OVERDUE = "overdue";
    private static final String ACTIVE_RUN_HEALTH_RUNNING = "running";
    private static final String PERFORMANCE_HEALTH_IDLE = "idle";
    private static final String PERFORMANCE_HEALTH_OK = "ok";
    private static final String PERFORMANCE_HEALTH_SLOW = "slow";
    private static final String ATTENTION_LEVEL_CRITICAL = "critical";
    private static final String ATTENTION_LEVEL_NONE = "none";
    private static final String ATTENTION_LEVEL_WAITING = "waiting";
    private static final String ATTENTION_LEVEL_WARNING = "warning";
    private static final String ATTENTION_LEVEL_WORK = "work";
    private static final String ATTENTION_REASON_CAUGHT_UP = "caught_up";
    private static final String ATTENTION_REASON_ESCALATED_FAILURES = "escalated_failures";
    private static final String ATTENTION_REASON_LAST_SYNC_FAILED = "last_sync_failed";
    private static final String ATTENTION_REASON_PENDING_SYNC = "pending_sync";
    private static final String ATTENTION_REASON_RETRY_READY = "retry_ready";
    private static final String ATTENTION_REASON_SYNC_IN_PROGRESS = "sync_in_progress";
    private static final String ATTENTION_REASON_SYNC_OVERDUE = "sync_overdue";
    private static final String DISPATCH_SKIPPED_IN_PROGRESS = "dispatch_in_progress";
    private static final String DISPATCH_SKIPPED_NO_RUNNABLE_SYNC = "no_runnable_sync";
    private static final String DISPATCH_STOPPED_MAX_RUNS_REACHED = "max_runs_reached";
    private static final String DISPATCH_STOPPED_RUN_FAILED = "run_failed";
    private static final String DISPATCH_HISTORY_OUTCOME_COMPLETED = "completed";
    private static final String DISPATCH_HISTORY_OUTCOME_FAILED = "failed";
    private static final String DISPATCH_HISTORY_OUTCOME_SKIPPED = "skipped";
    private static final String MEMORY_SYNC_RUN_PATH = "/media/events/memory-snapshots/sync";
    private static final String MEMORY_SYNC_RETRY_PATH = "/media/events/memory-snapshots/retry";
    private static final String RETRY_AFTER_HEADER = "Retry-After";
    private static final Set<String> CONTENT_TYPES = Set.of(
            "image/jpeg",
            "image/png",
            "image/webp",
            "image/heic",
            "video/mp4");
    private static final Set<String> PURPOSES = Set.of(
            "memory_photo",
            "avatar",
            "event_cover",
            "anchor_media");
    private static final Set<String> MEMORY_REFERENCE_PURPOSES = Set.of("memory_photo", "anchor_media");

    private final MediaRepository repository;
    private final MediaMemorySnapshotSyncOpsStore syncOpsStore;
    private final MediaStorageSigner storageSigner;
    private final MediaStorageVerifier storageVerifier;
    private final MediaMemorySnapshotSyncClient memorySnapshotSyncClient;
    private final int memorySnapshotSyncTimeoutSeconds;
    private final Map<String, ActiveMemorySnapshotSyncRun> activeMemorySnapshotSyncConsumers =
            new ConcurrentHashMap<>();
    private final AtomicReference<ActiveMemorySnapshotSyncDispatch> activeMemorySnapshotSyncDispatch =
            new AtomicReference<>();

    @Inject
    public MediaService(
            MediaRepository repository,
            MediaMemorySnapshotSyncOpsStore syncOpsStore,
            MediaStorageSigner storageSigner,
            MediaStorageVerifier storageVerifier,
            MediaMemorySnapshotSyncClient memorySnapshotSyncClient,
            @ConfigProperty(
                    name = "jezaku.media.memory-sync.request-timeout-seconds",
                    defaultValue = "5")
                    int memorySnapshotSyncTimeoutSeconds) {
        this.repository = repository;
        this.syncOpsStore = syncOpsStore;
        this.storageSigner = storageSigner;
        this.storageVerifier = storageVerifier;
        this.memorySnapshotSyncClient = memorySnapshotSyncClient;
        this.memorySnapshotSyncTimeoutSeconds = normalizeMemorySnapshotSyncTimeoutSeconds(
                memorySnapshotSyncTimeoutSeconds);
        seed();
    }

    public Uni<UploadResponse> createUpload(UploadCreateRequest request) {
        return Uni.createFrom().item(() -> {
            validateUploadCreate(request);
            Instant now = Instant.now();
            String uploadId = "upload_" + UUID.randomUUID();
            String fileName = normalizeFileName(request.fileName());
            String ownerId = requireText(request.ownerId(), "ownerId");
            String contentType = normalizeChoice(request.contentType(), CONTENT_TYPES, "contentType");
            String purpose = normalizeChoice(request.purpose(), PURPOSES, "purpose");
            MediaStorageUrls storageUrls = storageSigner.signUpload(uploadId, ownerId, purpose, fileName);
            UploadRecord upload = new UploadRecord(
                    uploadId,
                    ownerId,
                    fileName,
                    contentType,
                    request.byteSize(),
                    optionalTrim(request.checksumSha256(), ""),
                    purpose,
                    normalizeTags(request.tags()),
                    storageUrls.objectKey(),
                    storageUrls.uploadUrl(),
                    storageUrls.mediaUrl(),
                    "requested",
                    "pending",
                    now.plus(UPLOAD_TTL),
                    now,
                    now);
            repository.saveUpload(upload);
            return toUploadResponse(upload);
        });
    }

    public Uni<MediaResponse> completeUpload(String uploadId, UploadCompleteRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            UploadRecord upload = repository.findUploadById(requireText(uploadId, "uploadId"));
            if (upload == null) {
                throw new NotFoundException("Upload not found: " + uploadId);
            }
            String ownerId = requireText(request.ownerId(), "ownerId");
            if (!upload.ownerId().equals(ownerId)) {
                throw new ForbiddenException("Upload owner mismatch");
            }
            if (!"requested".equals(upload.status())) {
                throw new WebApplicationException("Upload is already completed", Response.Status.CONFLICT);
            }
            if (upload.expiresAt().isBefore(Instant.now())) {
                throw new WebApplicationException("Upload has expired", Response.Status.CONFLICT);
            }
            long reportedByteSize = normalizeBoundedLong(
                    request.byteSize(),
                    upload.byteSize(),
                    1L,
                    MAX_UPLOAD_BYTES,
                    "byteSize");
            String reportedChecksum = optionalTrim(request.checksumSha256(), upload.checksumSha256());
            MediaStorageVerification verification = storageVerifier.verifyCompletedUpload(
                    upload,
                    reportedByteSize,
                    reportedChecksum);
            Instant now = Instant.now();
            UploadRecord completed = upload.withCompletion(
                    verification.byteSize(),
                    verification.checksumSha256(),
                    now);
            repository.saveUpload(completed);
            String mediaId = "media_" + UUID.randomUUID();
            MediaRecord record = new MediaRecord(
                    mediaId,
                    completed.ownerId(),
                    completed.fileName(),
                    completed.contentType(),
                    completed.byteSize(),
                    completed.checksumSha256(),
                    completed.purpose(),
                    completed.tags(),
                    completed.objectKey(),
                    completed.mediaUrl(),
                    STATUS_ACTIVE,
                    completed.moderationStatus(),
                    completed.createdAt(),
                    now);
            repository.saveMedia(record);
            emitLifecycleEvent("completed", record, now);
            return toMediaResponse(record);
        });
    }

    public Uni<MediaResponse> get(String mediaId) {
        return Uni.createFrom().item(() -> toMediaResponse(requireActiveMedia(mediaId)));
    }

    public Uni<MediaReferenceResponse> reference(String mediaId) {
        return Uni.createFrom().item(() -> toMediaReferenceResponse(requireMedia(mediaId)));
    }

    public Uni<MediaReferenceBatchResponse> references(MediaReferenceBatchRequest request) {
        return Uni.createFrom().item(() -> {
            List<String> mediaIds = normalizeReferenceMediaIds(request);
            List<MediaReferenceResponse> references = mediaIds.stream()
                    .map(repository::findMediaById)
                    .filter(record -> record != null && !STATUS_DELETED.equals(record.status()))
                    .map(this::toMediaReferenceResponse)
                    .toList();
            Set<String> resolvedIds = references.stream()
                    .map(MediaReferenceResponse::mediaId)
                    .collect(java.util.stream.Collectors.toSet());
            List<String> missingMediaIds = mediaIds.stream()
                    .filter(mediaId -> !resolvedIds.contains(mediaId))
                    .toList();
            return new MediaReferenceBatchResponse(
                    mediaIds.size(),
                    references.size(),
                    references,
                    missingMediaIds);
        });
    }

    public Uni<MediaListResponse> userMedia(String ownerId) {
        return Uni.createFrom().item(() -> {
            String normalizedOwnerId = requireText(ownerId, "ownerId");
            List<MediaResponse> result = repository.findAllMedia().stream()
                    .filter(record -> record.ownerId().equals(normalizedOwnerId))
                    .filter(record -> STATUS_ACTIVE.equals(record.status()))
                    .sorted(Comparator.comparing(MediaRecord::createdAt).reversed())
                    .map(this::toMediaResponse)
                    .toList();
            return new MediaListResponse(normalizedOwnerId, result.size(), result);
        });
    }

    public Uni<Void> delete(String mediaId, String ownerId) {
        return Uni.createFrom().item(() -> {
            MediaRecord record = requireMedia(mediaId);
            String normalizedOwnerId = requireText(ownerId, "ownerId");
            if (!record.ownerId().equals(normalizedOwnerId)) {
                throw new ForbiddenException("Media owner mismatch");
            }
            Instant now = Instant.now();
            MediaRecord deleted = record.withStatus(STATUS_DELETED, now);
            repository.saveMedia(deleted);
            emitLifecycleEvent("deleted", deleted, now);
            return null;
        });
    }

    public Uni<MediaResponse> moderate(String mediaId, ModerationUpdateRequest request) {
        return Uni.createFrom().item(() -> {
            if (request == null) {
                throw new BadRequestException("Request body is required");
            }
            String reviewerId = requireText(request.reviewerId(), "reviewerId");
            String moderationStatus = normalizeChoice(request.moderationStatus(), MEDIA_MODERATION_STATUSES,
                    "moderationStatus");
            String reason = normalizeModerationReason(request.reason());
            MediaRecord record = requireMedia(mediaId);
            Instant now = Instant.now();
            MediaRecord moderated = record.withModeration(
                    moderationStatus,
                    statusForModeration(moderationStatus),
                    now);
            repository.saveMedia(moderated);
            repository.saveModerationEvent(new MediaModerationEvent(
                    "media_moderation_" + UUID.randomUUID(),
                    record.mediaId(),
                    reviewerId,
                    moderationStatus,
                    record.status(),
                    moderated.status(),
                    reason,
                    now));
            emitLifecycleEvent("moderated", moderated, now);
            return toMediaResponse(moderated);
        });
    }

    public Uni<MediaLifecycleEventsResponse> lifecycleEvents(Long afterSequence, Integer limit) {
        return Uni.createFrom().item(() -> {
            long normalizedAfterSequence = normalizeAfterSequence(afterSequence);
            int normalizedLimit = normalizeBoundedInt(limit, DEFAULT_EVENT_LIMIT, 1, MAX_EVENT_LIMIT, "limit");
            List<MediaLifecycleEventRecord> records = repository.findLifecycleEventsAfter(
                    normalizedAfterSequence,
                    normalizedLimit + 1);
            boolean hasMore = records.size() > normalizedLimit;
            List<MediaLifecycleEventResponse> events = records.stream()
                    .limit(normalizedLimit)
                    .map(this::toLifecycleEventResponse)
                    .toList();
            long lastSequence = events.isEmpty()
                    ? normalizedAfterSequence
                    : events.getLast().sequence();
            return new MediaLifecycleEventsResponse(
                    normalizedAfterSequence,
                    lastSequence,
                    hasMore,
                    events.size(),
                    events);
        });
    }

    public Uni<MediaMemorySnapshotSyncResponse> memorySnapshotSync(String consumerId, Long afterSequence, Integer limit) {
        return Uni.createFrom().item(() -> buildMemorySnapshotSync(consumerId, afterSequence, limit));
    }

    public Uni<MediaMemorySnapshotSyncRunResponse> runMemorySnapshotSync(MediaMemorySnapshotSyncRunRequest request) {
        return Uni.createFrom()
                .item(() -> runMemorySnapshotSyncNow(request))
                .runSubscriptionOn(Infrastructure.getDefaultWorkerPool());
    }

    public Uni<MediaMemorySnapshotSyncRunResponse> retryMemorySnapshotSync(
            MediaMemorySnapshotSyncRetryRequest request) {
        return Uni.createFrom()
                .item(() -> {
                    String consumerId = normalizeConsumerId(request == null ? null : request.consumerId());
                    MediaMemorySnapshotSyncFailureSummary failure = syncFailureSummary(
                            recentSyncRuns(consumerId),
                            Instant.now());
                    if (failure.consecutiveFailureCount() > 0
                            && !failure.retryReady()
                            && !forceRetry(request)) {
                        throw retryBackoffException(failure);
                    }
                    return runMemorySnapshotSyncNow(new MediaMemorySnapshotSyncRunRequest(
                            consumerId,
                            null,
                            request == null ? null : request.limit(),
                            request == null ? null : request.memoryBaseUrl()));
                })
                .runSubscriptionOn(Infrastructure.getDefaultWorkerPool());
    }

    public Uni<MediaMemorySnapshotSyncDispatchResponse> dispatchMemorySnapshotSync(
            MediaMemorySnapshotSyncDispatchRequest request) {
        return Uni.createFrom()
                .item(() -> dispatchMemorySnapshotSyncNow(request))
                .runSubscriptionOn(Infrastructure.getDefaultWorkerPool());
    }

    private MediaMemorySnapshotSyncDispatchResponse dispatchMemorySnapshotSyncNow(
            MediaMemorySnapshotSyncDispatchRequest request) {
        String dispatchId = nextMemorySnapshotSyncDispatchId();
        int maxRuns = normalizeBoundedInt(
                request == null ? null : request.maxRuns(),
                DEFAULT_SYNC_DISPATCH_RUN_LIMIT,
                1,
                MAX_SYNC_DISPATCH_RUN_LIMIT,
                "maxRuns");
        Instant checkedAt = Instant.now();
        ActiveMemorySnapshotSyncDispatch activeDispatch = new ActiveMemorySnapshotSyncDispatch(
                dispatchId,
                checkedAt,
                maxRuns);
        while (!activeMemorySnapshotSyncDispatch.compareAndSet(null, activeDispatch)) {
            ActiveMemorySnapshotSyncDispatch existingDispatch = activeMemorySnapshotSyncDispatch.get();
            if (existingDispatch != null) {
                return skippedMemorySnapshotSyncDispatch(
                        dispatchId,
                        maxRuns,
                        DISPATCH_SKIPPED_IN_PROGRESS,
                        activeDispatch(existingDispatch, checkedAt),
                        checkedAt);
            }
        }
        try {
            return dispatchMemorySnapshotSyncLocked(request, activeDispatch, checkedAt);
        } finally {
            activeMemorySnapshotSyncDispatch.compareAndSet(activeDispatch, null);
        }
    }

    private MediaMemorySnapshotSyncDispatchResponse skippedMemorySnapshotSyncDispatch(
            String dispatchId,
            int maxRuns,
            String skippedReason,
            MediaMemorySnapshotSyncActiveDispatch activeDispatch,
            Instant checkedAt) {
        List<MediaMemorySnapshotSyncStatusResponse> statuses = memorySnapshotSyncStatusesNow(checkedAt);
        Instant completedAt = Instant.now();
        return recordMemorySnapshotSyncDispatch(new MediaMemorySnapshotSyncDispatchResponse(
                dispatchId,
                false,
                skippedReason,
                skippedReason,
                syncStatusesHeadline(statuses),
                null,
                null,
                List.of(),
                maxRuns,
                0,
                activeDispatch,
                checkedAt,
                completedAt,
                durationMillis(checkedAt, completedAt)));
    }

    private MediaMemorySnapshotSyncDispatchResponse dispatchMemorySnapshotSyncLocked(
            MediaMemorySnapshotSyncDispatchRequest request,
            ActiveMemorySnapshotSyncDispatch activeDispatch,
            Instant checkedAt) {
        int maxRuns = activeDispatch.maxRuns();
        MediaMemorySnapshotSyncStatusesHeadline headline = null;
        MediaMemorySnapshotSyncRunHint firstRecommendedRun = null;
        List<MediaMemorySnapshotSyncRunResponse> runs = new ArrayList<>();
        String stoppedReason = null;

        for (int runIndex = 0; runIndex < maxRuns; runIndex++) {
            Instant statusCheckedAt = runIndex == 0 ? checkedAt : Instant.now();
            List<MediaMemorySnapshotSyncStatusResponse> statuses = memorySnapshotSyncStatusesNow(statusCheckedAt);
            if (headline == null) {
                headline = syncStatusesHeadline(statuses);
            }
            MediaMemorySnapshotSyncRunHint recommendedRun = recommendedStatusRun(statuses);
            if (recommendedRun == null) {
                stoppedReason = DISPATCH_SKIPPED_NO_RUNNABLE_SYNC;
                break;
            }

            MediaMemorySnapshotSyncRunHint dispatchRun = dispatchRunHint(recommendedRun, request);
            if (firstRecommendedRun == null) {
                firstRecommendedRun = dispatchRun;
            }
            MediaMemorySnapshotSyncRunResponse run = runMemorySnapshotSyncNow(
                    dispatchRunRequest(dispatchRun, request),
                    false);
            runs.add(run);
            if (SYNC_OUTCOME_FAILED.equals(run.outcome())) {
                stoppedReason = DISPATCH_STOPPED_RUN_FAILED;
                break;
            }
        }
        if (stoppedReason == null) {
            stoppedReason = DISPATCH_STOPPED_MAX_RUNS_REACHED;
        }

        boolean dispatched = !runs.isEmpty();
        Instant completedAt = Instant.now();
        return recordMemorySnapshotSyncDispatch(new MediaMemorySnapshotSyncDispatchResponse(
                activeDispatch.dispatchId(),
                dispatched,
                dispatched ? null : stoppedReason,
                stoppedReason,
                headline,
                firstRecommendedRun,
                dispatched ? runs.getLast() : null,
                List.copyOf(runs),
                maxRuns,
                runs.size(),
                activeDispatch(null, Instant.now()),
                checkedAt,
                completedAt,
                durationMillis(checkedAt, completedAt)));
    }

    private MediaMemorySnapshotSyncDispatchResponse recordMemorySnapshotSyncDispatch(
            MediaMemorySnapshotSyncDispatchResponse response) {
        syncOpsStore.saveMemorySnapshotSyncDispatch(toSyncDispatchRecord(response));
        return response;
    }

    private MediaMemorySnapshotSyncDispatchHistoryResponse syncDispatchHistoryResponse(int normalizedLimit) {
        List<MediaMemorySnapshotSyncDispatchHistoryEntry> dispatches =
                syncOpsStore.findMemorySnapshotSyncDispatches(normalizedLimit)
                        .stream()
                        .map(this::toSyncDispatchHistoryEntry)
                        .toList();
        return new MediaMemorySnapshotSyncDispatchHistoryResponse(
                dispatches.size(),
                syncDispatchHistorySummary(dispatches),
                dispatches);
    }

    public Uni<MediaMemorySnapshotSyncDispatchHistoryResponse> memorySnapshotSyncDispatches(Integer limit) {
        return Uni.createFrom().item(() -> {
            int normalizedLimit = normalizeBoundedInt(
                    limit,
                    DEFAULT_SYNC_DISPATCH_HISTORY_LIMIT,
                    1,
                    MAX_SYNC_DISPATCH_HISTORY_LIMIT,
                    "limit");
            return syncDispatchHistoryResponse(normalizedLimit);
        });
    }

    private MediaMemorySnapshotSyncRunHint dispatchRunHint(
            MediaMemorySnapshotSyncRunHint recommendedRun,
            MediaMemorySnapshotSyncDispatchRequest request) {
        int limit = normalizeBoundedInt(
                request == null ? null : request.limit(),
                recommendedRun.limit(),
                1,
                MAX_EVENT_LIMIT,
                "limit");
        return new MediaMemorySnapshotSyncRunHint(
                recommendedRun.shouldRun(),
                recommendedRun.retryable(),
                recommendedRun.method(),
                recommendedRun.path(),
                recommendedRun.consumerId(),
                recommendedRun.afterSequence(),
                limit);
    }

    private MediaMemorySnapshotSyncRunRequest dispatchRunRequest(
            MediaMemorySnapshotSyncRunHint dispatchRun,
            MediaMemorySnapshotSyncDispatchRequest request) {
        return new MediaMemorySnapshotSyncRunRequest(
                dispatchRun.consumerId(),
                MEMORY_SYNC_RETRY_PATH.equals(dispatchRun.path()) ? null : dispatchRun.afterSequence(),
                dispatchRun.limit(),
                request == null ? null : request.memoryBaseUrl());
    }

    private MediaMemorySnapshotSyncRunResponse runMemorySnapshotSyncNow(MediaMemorySnapshotSyncRunRequest request) {
        return runMemorySnapshotSyncNow(request, true);
    }

    private MediaMemorySnapshotSyncRunResponse runMemorySnapshotSyncNow(
            MediaMemorySnapshotSyncRunRequest request,
            boolean throwOnFailure) {
        String consumerId = normalizeConsumerId(request == null ? null : request.consumerId());
        ActiveMemorySnapshotSyncRun activeRun = new ActiveMemorySnapshotSyncRun(
                nextMemorySnapshotSyncRunId(),
                Instant.now());
        if (activeMemorySnapshotSyncConsumers.putIfAbsent(consumerId, activeRun) != null) {
            throw new WebApplicationException(
                    "Memory snapshot sync is already running for consumerId " + consumerId,
                    Response.Status.CONFLICT);
        }
        try {
            return runMemorySnapshotSyncLocked(request, consumerId, activeRun, throwOnFailure);
        } finally {
            activeMemorySnapshotSyncConsumers.remove(consumerId);
        }
    }

    private MediaMemorySnapshotSyncRunResponse runMemorySnapshotSyncLocked(
            MediaMemorySnapshotSyncRunRequest request,
            String consumerId,
            ActiveMemorySnapshotSyncRun activeRun,
            boolean throwOnFailure) {
        String runId = activeRun.runId();
        Instant startedAt = activeRun.startedAt();
        Long afterSequence = request == null ? null : request.afterSequence();
        Integer limit = request == null ? null : request.limit();
        String memoryBaseUrl = request == null ? null : optionalTrim(request.memoryBaseUrl(), null);
        MediaMemorySnapshotSyncResponse projection = buildMemorySnapshotSync(consumerId, afterSequence, limit);
        MemoryMediaSnapshotApplyResponse<Map<String, Object>> memoryResponse = null;
        boolean memoryCalled = false;
        try {
            if (projection.snapshotCount() > 0) {
                memoryCalled = true;
                memoryResponse = memorySnapshotSyncClient.apply(memoryBaseUrl, projection.memoryRequest());
            }
            MediaSyncCheckpointResponse checkpoint = advanceMemorySnapshotCheckpoint(
                    new MediaSyncCheckpointRequest(projection.consumerId(), projection.lastSequence()));
            String outcome = memoryCalled ? SYNC_OUTCOME_SUCCEEDED : SYNC_OUTCOME_NOOP;
            Instant completedAt = Instant.now();
            syncOpsStore.saveMemorySnapshotSyncRun(toSyncRunRecord(
                    runId,
                    projection,
                    memoryCalled,
                    outcome,
                    "",
                    startedAt,
                    completedAt));
            return new MediaMemorySnapshotSyncRunResponse(
                    runId,
                    projection.consumerId(),
                    projection.afterSequence(),
                    projection.lastSequence(),
                    projection.hasMore(),
                    projection.eventCount(),
                    projection.snapshotCount(),
                    memoryCalled,
                    outcome,
                    "",
                    startedAt,
                    completedAt,
                    durationMillis(startedAt, completedAt),
                    memoryResponse,
                    checkpoint);
        } catch (RuntimeException exception) {
            String errorMessage = optionalTrim(exception.getMessage(), "");
            Instant completedAt = Instant.now();
            syncOpsStore.saveMemorySnapshotSyncRun(toSyncRunRecord(
                    runId,
                    projection,
                    memoryCalled,
                    SYNC_OUTCOME_FAILED,
                    errorMessage,
                    startedAt,
                    completedAt));
            if (!throwOnFailure) {
                return new MediaMemorySnapshotSyncRunResponse(
                        runId,
                        projection.consumerId(),
                        projection.afterSequence(),
                        projection.lastSequence(),
                        projection.hasMore(),
                        projection.eventCount(),
                        projection.snapshotCount(),
                        memoryCalled,
                        SYNC_OUTCOME_FAILED,
                        errorMessage,
                        startedAt,
                        completedAt,
                        durationMillis(startedAt, completedAt),
                        memoryResponse,
                        null);
            }
            throw exception;
        }
    }

    private boolean forceRetry(MediaMemorySnapshotSyncRetryRequest request) {
        return request != null && Boolean.TRUE.equals(request.force());
    }

    private WebApplicationException retryBackoffException(MediaMemorySnapshotSyncFailureSummary failure) {
        Response response = Response.status(Response.Status.TOO_MANY_REQUESTS)
                .header(RETRY_AFTER_HEADER, retryAfterSeconds(failure))
                .build();
        return new WebApplicationException(
                "Memory snapshot sync retry is waiting for backoff window",
                response);
    }

    private long retryAfterSeconds(MediaMemorySnapshotSyncFailureSummary failure) {
        if (failure.nextRetryAt() == null) {
            return Math.max(1, failure.nextRetryDelaySeconds());
        }
        long millis = Duration.between(Instant.now(), failure.nextRetryAt()).toMillis();
        if (millis <= 0) {
            return 1;
        }
        return Math.max(1, (millis + 999) / 1_000);
    }

    private List<MediaMemorySnapshotSyncRunHistoryEntry> recentSyncRuns(String consumerId) {
        return syncOpsStore.findMemorySnapshotSyncRuns(
                        consumerId,
                        MAX_SYNC_RUN_HISTORY_LIMIT)
                .stream()
                .map(this::toSyncRunHistoryEntry)
                .toList();
    }

    private MediaMemorySnapshotSyncRunHistoryResponse syncRunHistoryResponse(
            String normalizedConsumerId,
            int normalizedLimit) {
        List<MediaMemorySnapshotSyncRunHistoryEntry> runs = syncOpsStore.findMemorySnapshotSyncRuns(
                        normalizedConsumerId,
                        normalizedLimit)
                .stream()
                .map(this::toSyncRunHistoryEntry)
                .toList();
        return new MediaMemorySnapshotSyncRunHistoryResponse(
                normalizedConsumerId,
                runs.size(),
                syncRunHistorySummary(runs),
                runs);
    }

    public Uni<MediaMemorySnapshotSyncRunHistoryResponse> memorySnapshotSyncRuns(
            String consumerId,
            Integer limit) {
        return Uni.createFrom().item(() -> {
            String normalizedConsumerId = normalizeConsumerId(consumerId);
            int normalizedLimit = normalizeBoundedInt(
                    limit,
                    DEFAULT_SYNC_RUN_HISTORY_LIMIT,
                    1,
                    MAX_SYNC_RUN_HISTORY_LIMIT,
                    "limit");
            return syncRunHistoryResponse(normalizedConsumerId, normalizedLimit);
        });
    }

    public Uni<MediaMemorySnapshotSyncStatusResponse> memorySnapshotSyncStatus(String consumerId) {
        return Uni.createFrom().item(() -> memorySnapshotSyncStatusNow(
                normalizeConsumerId(consumerId),
                Instant.now()));
    }

    public Uni<MediaMemorySnapshotSyncStatusesResponse> memorySnapshotSyncStatuses(Integer limit) {
        return Uni.createFrom().item(() -> {
            int normalizedLimit = normalizeBoundedInt(
                    limit,
                    DEFAULT_SYNC_STATUS_LIMIT,
                    1,
                    MAX_SYNC_STATUS_LIMIT,
                    "limit");
            Instant checkedAt = Instant.now();
            List<MediaMemorySnapshotSyncStatusResponse> allStatuses = memorySnapshotSyncStatusesNow(checkedAt);
            List<MediaMemorySnapshotSyncStatusResponse> statuses = allStatuses
                    .stream()
                    .limit(normalizedLimit)
                    .toList();
            return new MediaMemorySnapshotSyncStatusesResponse(
                    statuses.size(),
                    allStatuses.size(),
                    allStatuses.size() > statuses.size(),
                    checkedAt,
                    syncStatusesSummary(allStatuses),
                    syncStatusesHeadline(allStatuses),
                    recommendedStatusRun(allStatuses),
                    activeDispatch(activeMemorySnapshotSyncDispatch.get(), checkedAt),
                    statuses);
        });
    }

    public Uni<MediaMemorySnapshotSyncOpsResponse> memorySnapshotSyncOps(
            Integer limit,
            Integer historyLimit) {
        return Uni.createFrom().item(() -> {
            int normalizedLimit = normalizeBoundedInt(
                    limit,
                    DEFAULT_SYNC_STATUS_LIMIT,
                    1,
                    MAX_SYNC_STATUS_LIMIT,
                    "limit");
            int normalizedHistoryLimit = normalizeBoundedInt(
                    historyLimit,
                    DEFAULT_SYNC_OPS_HISTORY_LIMIT,
                    1,
                    MAX_SYNC_OPS_HISTORY_LIMIT,
                    "historyLimit");
            Instant checkedAt = Instant.now();
            List<MediaMemorySnapshotSyncStatusResponse> allStatuses =
                    memorySnapshotSyncStatusesNow(checkedAt);
            List<MediaMemorySnapshotSyncStatusResponse> statuses = allStatuses.stream()
                    .limit(normalizedLimit)
                    .toList();
            MediaMemorySnapshotSyncStatusesHeadline headline = syncStatusesHeadline(allStatuses);
            MediaMemorySnapshotSyncRunHint recommendedRun = recommendedStatusRun(allStatuses);
            MediaMemorySnapshotSyncActiveDispatch activeDispatch = activeDispatch(
                    activeMemorySnapshotSyncDispatch.get(),
                    checkedAt);
            MediaMemorySnapshotSyncStatusResponse primaryStatus = statuses.isEmpty()
                    ? null
                    : statuses.getFirst();
            String primaryConsumerId = primaryStatus == null
                    ? normalizeConsumerId(null)
                    : primaryStatus.consumerId();
            MediaMemorySnapshotSyncRunHistoryResponse primaryRunHistory =
                    syncRunHistoryResponse(primaryConsumerId, normalizedHistoryLimit);
            MediaMemorySnapshotSyncDispatchHistoryResponse dispatchHistory =
                    syncDispatchHistoryResponse(normalizedHistoryLimit);
            return new MediaMemorySnapshotSyncOpsResponse(
                    syncOpsHealth(headline, activeDispatch, primaryRunHistory.summary(), dispatchHistory.summary()),
                    syncOpsRecommendedAction(headline, activeDispatch),
                    checkedAt,
                    statuses.size(),
                    allStatuses.size(),
                    allStatuses.size() > statuses.size(),
                    syncStatusesSummary(allStatuses),
                    headline,
                    recommendedRun,
                    activeDispatch,
                    primaryStatus,
                    primaryRunHistory,
                    dispatchHistory,
                    statuses);
        });
    }

    public Uni<MediaSyncCheckpointResponse> memorySnapshotCheckpoint(String consumerId) {
        return Uni.createFrom().item(() -> toCheckpointResponse(normalizeConsumerId(consumerId)));
    }

    public Uni<MediaSyncCheckpointResponse> updateMemorySnapshotCheckpoint(MediaSyncCheckpointRequest request) {
        return Uni.createFrom().item(() -> advanceMemorySnapshotCheckpoint(request));
    }

    private List<MediaMemorySnapshotSyncStatusResponse> memorySnapshotSyncStatusesNow(Instant checkedAt) {
        return memorySnapshotSyncConsumerIds()
                .stream()
                .map(consumerId -> memorySnapshotSyncStatusNow(consumerId, checkedAt))
                .sorted(this::compareSyncStatusPriority)
                .toList();
    }

    private String syncState(long sequenceLag, MediaMemorySnapshotSyncRunHistoryEntry lastRun) {
        if (sequenceLag > 0
                && lastRun != null
                && SYNC_OUTCOME_FAILED.equals(lastRun.outcome())) {
            return SYNC_STATE_FAILED;
        }
        if (sequenceLag > 0) {
            return SYNC_STATE_PENDING;
        }
        return SYNC_STATE_HEALTHY;
    }

    private String recommendedSyncAction(String syncState) {
        if (SYNC_STATE_FAILED.equals(syncState)) {
            return SYNC_ACTION_INSPECT_LAST_RUN;
        }
        if (SYNC_STATE_PENDING.equals(syncState)) {
            return SYNC_ACTION_RUN;
        }
        return SYNC_ACTION_NONE;
    }

    private String syncStatusReason(String syncState, int pendingSnapshotCount) {
        if (SYNC_STATE_FAILED.equals(syncState)) {
            return "last sync run failed while pending snapshots remain";
        }
        if (SYNC_STATE_PENDING.equals(syncState) && pendingSnapshotCount > 0) {
            return "memory snapshots are waiting for sync";
        }
        if (SYNC_STATE_PENDING.equals(syncState)) {
            return "lifecycle events are waiting for checkpoint advancement";
        }
        return "memory snapshot sync is caught up";
    }

    private MediaMemorySnapshotSyncRunHint syncRunHint(
            String consumerId,
            long checkpointSequence,
            int pendingEventCount,
            String syncState) {
        boolean shouldRun = pendingEventCount > 0;
        return new MediaMemorySnapshotSyncRunHint(
                shouldRun,
                shouldRun && SYNC_STATE_FAILED.equals(syncState),
                "POST",
                MEMORY_SYNC_RUN_PATH,
                consumerId,
                checkpointSequence,
                suggestedSyncLimit(pendingEventCount));
    }

    private MediaMemorySnapshotSyncStatusResponse memorySnapshotSyncStatusNow(
            String normalizedConsumerId,
            Instant checkedAt) {
        long checkpointSequence = checkpointSequence(normalizedConsumerId);
        long latestSequence = repository.latestLifecycleSequence();
        List<MediaLifecycleEventRecord> pendingEvents = repository.findLifecycleEventsAfter(
                checkpointSequence,
                Integer.MAX_VALUE);
        int pendingSnapshotCount = (int) pendingEvents.stream()
                .filter(event -> MEMORY_REFERENCE_PURPOSES.contains(event.purpose()))
                .count();
        long sequenceLag = Math.max(0L, latestSequence - checkpointSequence);
        int pendingEventCount = pendingEvents.size();
        List<MediaMemorySnapshotSyncRunHistoryEntry> recentRuns = recentSyncRuns(normalizedConsumerId);
        MediaMemorySnapshotSyncRunHistoryEntry lastRun = recentRuns.stream()
                .findFirst()
                .orElse(null);
        String syncState = syncState(sequenceLag, lastRun);
        MediaMemorySnapshotSyncRunHint nextRun = syncRunHint(
                normalizedConsumerId,
                checkpointSequence,
                pendingEventCount,
                syncState);
        String recommendedAction = recommendedSyncAction(syncState);
        String statusReason = syncStatusReason(syncState, pendingSnapshotCount);
        MediaMemorySnapshotSyncActiveRun activeRun = activeRun(normalizedConsumerId, checkedAt);
        MediaMemorySnapshotSyncFailureSummary failure = syncFailureSummary(recentRuns, checkedAt);
        return new MediaMemorySnapshotSyncStatusResponse(
                normalizedConsumerId,
                checkpointSequence,
                latestSequence,
                sequenceLag,
                pendingEventCount,
                pendingSnapshotCount,
                pendingSnapshotCount > 0,
                syncState,
                recommendedAction,
                statusReason,
                syncAttention(syncState, recommendedAction, activeRun, failure),
                nextRun,
                activeRun,
                failure,
                lastRun,
                checkedAt);
    }

    private List<String> memorySnapshotSyncConsumerIds() {
        TreeSet<String> consumerIds = new TreeSet<>();
        consumerIds.add(DEFAULT_MEMORY_SYNC_CONSUMER_ID);
        consumerIds.addAll(syncOpsStore.findMemorySnapshotSyncConsumerIds());
        consumerIds.addAll(activeMemorySnapshotSyncConsumers.keySet());
        return List.copyOf(consumerIds);
    }

    private int compareSyncStatusPriority(
            MediaMemorySnapshotSyncStatusResponse left,
            MediaMemorySnapshotSyncStatusResponse right) {
        int priority = Integer.compare(syncStatusPriority(left), syncStatusPriority(right));
        if (priority != 0) {
            return priority;
        }
        int sequenceLag = Long.compare(right.sequenceLag(), left.sequenceLag());
        if (sequenceLag != 0) {
            return sequenceLag;
        }
        int pendingSnapshots = Integer.compare(right.pendingSnapshotCount(), left.pendingSnapshotCount());
        if (pendingSnapshots != 0) {
            return pendingSnapshots;
        }
        return left.consumerId().compareTo(right.consumerId());
    }

    private int syncStatusPriority(MediaMemorySnapshotSyncStatusResponse status) {
        return status.attention().priority();
    }

    private MediaMemorySnapshotSyncAttention syncAttention(
            String syncState,
            String recommendedAction,
            MediaMemorySnapshotSyncActiveRun activeRun,
            MediaMemorySnapshotSyncFailureSummary failure) {
        if (SYNC_STATE_FAILED.equals(syncState)) {
            return new MediaMemorySnapshotSyncAttention(
                    0,
                    ATTENTION_LEVEL_CRITICAL,
                    ATTENTION_REASON_LAST_SYNC_FAILED,
                    SYNC_ACTION_INSPECT_LAST_RUN);
        }
        if (activeRun.overdue()) {
            return new MediaMemorySnapshotSyncAttention(
                    1,
                    ATTENTION_LEVEL_CRITICAL,
                    ATTENTION_REASON_SYNC_OVERDUE,
                    ACTIVE_RUN_ACTION_INSPECT_MEMORY);
        }
        if (failure.escalationRecommended()) {
            return new MediaMemorySnapshotSyncAttention(
                    2,
                    ATTENTION_LEVEL_CRITICAL,
                    ATTENTION_REASON_ESCALATED_FAILURES,
                    SYNC_ACTION_INSPECT_LAST_RUN);
        }
        if (activeRun.inProgress()) {
            return new MediaMemorySnapshotSyncAttention(
                    3,
                    ATTENTION_LEVEL_WAITING,
                    ATTENTION_REASON_SYNC_IN_PROGRESS,
                    ACTIVE_RUN_ACTION_WAIT);
        }
        if (failure.retryReady()) {
            return new MediaMemorySnapshotSyncAttention(
                    4,
                    ATTENTION_LEVEL_WARNING,
                    ATTENTION_REASON_RETRY_READY,
                    SYNC_ACTION_RETRY);
        }
        if (SYNC_STATE_PENDING.equals(syncState)) {
            return new MediaMemorySnapshotSyncAttention(
                    5,
                    ATTENTION_LEVEL_WORK,
                    ATTENTION_REASON_PENDING_SYNC,
                    SYNC_ACTION_RUN);
        }
        return new MediaMemorySnapshotSyncAttention(
                6,
                ATTENTION_LEVEL_NONE,
                ATTENTION_REASON_CAUGHT_UP,
                recommendedAction);
    }

    private MediaMemorySnapshotSyncStatusesHeadline syncStatusesHeadline(
            List<MediaMemorySnapshotSyncStatusResponse> statuses) {
        if (statuses.isEmpty()) {
            return new MediaMemorySnapshotSyncStatusesHeadline(
                    null,
                    6,
                    ATTENTION_LEVEL_NONE,
                    ATTENTION_REASON_CAUGHT_UP,
                    SYNC_ACTION_NONE);
        }
        MediaMemorySnapshotSyncStatusResponse status = statuses.getFirst();
        MediaMemorySnapshotSyncAttention attention = status.attention();
        return new MediaMemorySnapshotSyncStatusesHeadline(
                status.consumerId(),
                attention.priority(),
                attention.level(),
                attention.reason(),
                attention.recommendedAction());
    }

    private MediaMemorySnapshotSyncRunHint recommendedStatusRun(
            List<MediaMemorySnapshotSyncStatusResponse> statuses) {
        return statuses.stream()
                .map(this::recommendedStatusRun)
                .filter(hint -> hint != null)
                .findFirst()
                .orElse(null);
    }

    private MediaMemorySnapshotSyncRunHint recommendedStatusRun(MediaMemorySnapshotSyncStatusResponse status) {
        if (status.activeRun().inProgress() || !status.nextRun().shouldRun()) {
            return null;
        }
        if (status.failure().hasFailure()) {
            if (!status.failure().retryReady()) {
                return null;
            }
            return new MediaMemorySnapshotSyncRunHint(
                    true,
                    true,
                    "POST",
                    MEMORY_SYNC_RETRY_PATH,
                    status.consumerId(),
                    status.checkpointSequence(),
                    status.nextRun().limit());
        }
        return status.nextRun();
    }

    private MediaMemorySnapshotSyncStatusesSummary syncStatusesSummary(
            List<MediaMemorySnapshotSyncStatusResponse> statuses) {
        int healthyCount = 0;
        int pendingCount = 0;
        int failedCount = 0;
        int activeRunCount = 0;
        int overdueRunCount = 0;
        int retryReadyCount = 0;
        int escalationRecommendedCount = 0;
        int totalPendingEventCount = 0;
        int totalPendingSnapshotCount = 0;
        long totalSequenceLag = 0L;
        for (MediaMemorySnapshotSyncStatusResponse status : statuses) {
            if (SYNC_STATE_HEALTHY.equals(status.syncState())) {
                healthyCount++;
            } else if (SYNC_STATE_PENDING.equals(status.syncState())) {
                pendingCount++;
            } else if (SYNC_STATE_FAILED.equals(status.syncState())) {
                failedCount++;
            }
            if (status.activeRun().inProgress()) {
                activeRunCount++;
            }
            if (status.activeRun().overdue()) {
                overdueRunCount++;
            }
            if (status.failure().retryReady()) {
                retryReadyCount++;
            }
            if (status.failure().escalationRecommended()) {
                escalationRecommendedCount++;
            }
            totalPendingEventCount += status.pendingEventCount();
            totalPendingSnapshotCount += status.pendingSnapshotCount();
            totalSequenceLag += status.sequenceLag();
        }
        return new MediaMemorySnapshotSyncStatusesSummary(
                healthyCount,
                pendingCount,
                failedCount,
                activeRunCount,
                overdueRunCount,
                retryReadyCount,
                escalationRecommendedCount,
                totalPendingEventCount,
                totalPendingSnapshotCount,
                totalSequenceLag);
    }

    private String syncOpsHealth(
            MediaMemorySnapshotSyncStatusesHeadline headline,
            MediaMemorySnapshotSyncActiveDispatch activeDispatch,
            MediaMemorySnapshotSyncRunHistorySummary runSummary,
            MediaMemorySnapshotSyncDispatchHistorySummary dispatchSummary) {
        if (headline != null && ATTENTION_LEVEL_CRITICAL.equals(headline.level())) {
            return ATTENTION_LEVEL_CRITICAL;
        }
        if (activeDispatch != null && activeDispatch.inProgress()) {
            return ATTENTION_LEVEL_WAITING;
        }
        if (headline != null && ATTENTION_LEVEL_WAITING.equals(headline.level())) {
            return ATTENTION_LEVEL_WAITING;
        }
        if (headline != null && ATTENTION_LEVEL_WARNING.equals(headline.level())) {
            return ATTENTION_LEVEL_WARNING;
        }
        if (dispatchSummary != null
                && DISPATCH_HISTORY_OUTCOME_FAILED.equals(dispatchSummary.latestOutcome())) {
            return ATTENTION_LEVEL_WARNING;
        }
        if (runSummary != null && PERFORMANCE_HEALTH_SLOW.equals(runSummary.performanceHealth())) {
            return PERFORMANCE_HEALTH_SLOW;
        }
        if (dispatchSummary != null && PERFORMANCE_HEALTH_SLOW.equals(dispatchSummary.performanceHealth())) {
            return PERFORMANCE_HEALTH_SLOW;
        }
        if (headline != null && ATTENTION_LEVEL_WORK.equals(headline.level())) {
            return ATTENTION_LEVEL_WORK;
        }
        return SYNC_STATE_HEALTHY;
    }

    private String syncOpsRecommendedAction(
            MediaMemorySnapshotSyncStatusesHeadline headline,
            MediaMemorySnapshotSyncActiveDispatch activeDispatch) {
        if (activeDispatch != null && activeDispatch.inProgress()) {
            return ACTIVE_DISPATCH_ACTION_WAIT;
        }
        return headline == null ? SYNC_ACTION_NONE : headline.recommendedAction();
    }

    private MediaMemorySnapshotSyncActiveRun activeRun(String consumerId, Instant checkedAt) {
        ActiveMemorySnapshotSyncRun activeRun = activeMemorySnapshotSyncConsumers.get(consumerId);
        if (activeRun == null) {
            return new MediaMemorySnapshotSyncActiveRun(
                    false,
                    null,
                    null,
                    null,
                    memorySnapshotSyncTimeoutSeconds,
                    false,
                    ACTIVE_RUN_HEALTH_IDLE,
                    ACTIVE_RUN_ACTION_NONE);
        }
        Instant startedAt = activeRun.startedAt();
        long runningSeconds = Math.max(0L, Duration.between(startedAt, checkedAt).toSeconds());
        boolean overdue = runningSeconds >= memorySnapshotSyncTimeoutSeconds;
        return new MediaMemorySnapshotSyncActiveRun(
                true,
                activeRun.runId(),
                startedAt,
                runningSeconds,
                memorySnapshotSyncTimeoutSeconds,
                overdue,
                overdue ? ACTIVE_RUN_HEALTH_OVERDUE : ACTIVE_RUN_HEALTH_RUNNING,
                overdue ? ACTIVE_RUN_ACTION_INSPECT_MEMORY : ACTIVE_RUN_ACTION_WAIT);
    }

    private MediaMemorySnapshotSyncActiveDispatch activeDispatch(
            ActiveMemorySnapshotSyncDispatch activeDispatch,
            Instant checkedAt) {
        if (activeDispatch == null) {
            return new MediaMemorySnapshotSyncActiveDispatch(
                    false,
                    null,
                    null,
                    null,
                    null,
                    ACTIVE_DISPATCH_HEALTH_IDLE,
                    ACTIVE_DISPATCH_ACTION_NONE);
        }
        Instant startedAt = activeDispatch.startedAt();
        long runningSeconds = Math.max(0L, Duration.between(startedAt, checkedAt).toSeconds());
        return new MediaMemorySnapshotSyncActiveDispatch(
                true,
                activeDispatch.dispatchId(),
                startedAt,
                runningSeconds,
                activeDispatch.maxRuns(),
                ACTIVE_DISPATCH_HEALTH_RUNNING,
                ACTIVE_DISPATCH_ACTION_WAIT);
    }

    private int normalizeMemorySnapshotSyncTimeoutSeconds(int timeoutSeconds) {
        return timeoutSeconds <= 0 ? DEFAULT_MEMORY_SYNC_TIMEOUT_SECONDS : timeoutSeconds;
    }

    private long durationMillis(Instant startedAt, Instant completedAt) {
        if (startedAt == null || completedAt == null) {
            return 0L;
        }
        return Math.max(0L, Duration.between(startedAt, completedAt).toMillis());
    }

    private long syncPerformanceSlowThresholdMillis() {
        return Math.max(1L, memorySnapshotSyncTimeoutSeconds * 1_000L);
    }

    private boolean isSlowSyncDuration(long durationMillis) {
        return durationMillis >= syncPerformanceSlowThresholdMillis();
    }

    private String performanceHealth(boolean hasHistory, int slowCount) {
        if (!hasHistory) {
            return PERFORMANCE_HEALTH_IDLE;
        }
        return slowCount > 0 ? PERFORMANCE_HEALTH_SLOW : PERFORMANCE_HEALTH_OK;
    }

    private String nextMemorySnapshotSyncRunId() {
        return "media_memory_sync_run_" + UUID.randomUUID();
    }

    private String nextMemorySnapshotSyncDispatchId() {
        return "media_memory_sync_dispatch_" + UUID.randomUUID();
    }

    private record ActiveMemorySnapshotSyncRun(String runId, Instant startedAt) {
    }

    private record ActiveMemorySnapshotSyncDispatch(String dispatchId, Instant startedAt, int maxRuns) {
    }

    private MediaMemorySnapshotSyncFailureSummary syncFailureSummary(
            List<MediaMemorySnapshotSyncRunHistoryEntry> recentRuns,
            Instant checkedAt) {
        int consecutiveFailureCount = 0;
        boolean countingConsecutiveFailures = true;
        MediaMemorySnapshotSyncRunHistoryEntry lastFailedRun = null;
        for (MediaMemorySnapshotSyncRunHistoryEntry run : recentRuns) {
            boolean failed = SYNC_OUTCOME_FAILED.equals(run.outcome());
            if (failed && lastFailedRun == null) {
                lastFailedRun = run;
            }
            if (countingConsecutiveFailures && failed) {
                consecutiveFailureCount++;
                continue;
            }
            countingConsecutiveFailures = false;
        }
        int nextRetryDelaySeconds = syncFailureRetryDelaySeconds(consecutiveFailureCount);
        Instant nextRetryAt = nextRetryAt(lastFailedRun, consecutiveFailureCount, nextRetryDelaySeconds);
        return new MediaMemorySnapshotSyncFailureSummary(
                lastFailedRun != null,
                consecutiveFailureCount,
                syncFailureSeverity(lastFailedRun != null, consecutiveFailureCount),
                nextRetryDelaySeconds,
                nextRetryAt,
                nextRetryAt != null && !checkedAt.isBefore(nextRetryAt),
                consecutiveFailureCount >= SYNC_FAILURE_ESCALATION_COUNT,
                lastFailedRun == null ? null : lastFailedRun.runId(),
                lastFailedRun == null ? null : lastFailedRun.errorMessage(),
                lastFailedRun == null ? null : lastFailedRun.completedAt());
    }

    private Instant nextRetryAt(
            MediaMemorySnapshotSyncRunHistoryEntry lastFailedRun,
            int consecutiveFailureCount,
            int retryDelaySeconds) {
        if (lastFailedRun == null || consecutiveFailureCount <= 0 || retryDelaySeconds <= 0) {
            return null;
        }
        return lastFailedRun.completedAt().plusSeconds(retryDelaySeconds);
    }

    private String syncFailureSeverity(boolean hasFailure, int consecutiveFailureCount) {
        if (!hasFailure) {
            return "none";
        }
        if (consecutiveFailureCount <= 0) {
            return "resolved";
        }
        if (consecutiveFailureCount >= SYNC_FAILURE_ESCALATION_COUNT) {
            return "critical";
        }
        return "warning";
    }

    private int syncFailureRetryDelaySeconds(int consecutiveFailureCount) {
        if (consecutiveFailureCount <= 0) {
            return 0;
        }
        if (consecutiveFailureCount == 1) {
            return SYNC_FAILURE_FIRST_RETRY_DELAY_SECONDS;
        }
        if (consecutiveFailureCount == 2) {
            return SYNC_FAILURE_SECOND_RETRY_DELAY_SECONDS;
        }
        return SYNC_FAILURE_ESCALATED_RETRY_DELAY_SECONDS;
    }

    private int suggestedSyncLimit(int pendingEventCount) {
        if (pendingEventCount <= 0) {
            return DEFAULT_EVENT_LIMIT;
        }
        return Math.min(pendingEventCount, MAX_EVENT_LIMIT);
    }

    public Uni<ModerationHistoryResponse> moderationHistory(String mediaId, String reviewerId) {
        return Uni.createFrom().item(() -> {
            MediaRecord record = requireMedia(mediaId);
            requireText(reviewerId, "reviewerId");
            List<ModerationEventResponse> events = repository.findModerationEventsByMediaId(record.mediaId()).stream()
                    .sorted(Comparator.comparing(MediaModerationEvent::createdAt).reversed())
                    .map(this::toModerationEventResponse)
                    .toList();
            return new ModerationHistoryResponse(record.mediaId(), events.size(), events);
        });
    }

    private void seed() {
        Instant now = Instant.now();
        addSeed(new MediaRecord(
                "media_seed_courtyard",
                "user_current",
                "courtyard.jpg",
                "image/jpeg",
                1_204_224,
                "seed-courtyard",
                "memory_photo",
                List.of("campus", "trail"),
                "memory_photo/user_current/media_seed_courtyard/courtyard.jpg",
                "https://cdn.jezaku.local/media/seed/courtyard.jpg",
                STATUS_ACTIVE,
                "approved",
                now.minusSeconds(460),
                now.minusSeconds(450)));
        addSeed(new MediaRecord(
                "media_seed_rooftop",
                "user_rooftop",
                "rooftop.webp",
                "image/webp",
                844_512,
                "seed-rooftop",
                "memory_photo",
                List.of("rooftop"),
                "memory_photo/user_rooftop/media_seed_rooftop/rooftop.webp",
                "https://cdn.jezaku.local/media/seed/rooftop.webp",
                STATUS_ACTIVE,
                "approved",
                now.minusSeconds(360),
                now.minusSeconds(350)));
        addSeed(new MediaRecord(
                "media_seed_pending",
                "user_current",
                "fresh-marker.png",
                "image/png",
                654_120,
                "seed-pending",
                "anchor_media",
                List.of("anchor"),
                "anchor_media/user_current/media_seed_pending/fresh-marker.png",
                "https://cdn.jezaku.local/media/seed/fresh-marker.png",
                STATUS_ACTIVE,
                "pending",
                now.minusSeconds(120),
                now.minusSeconds(110)));
    }

    private void addSeed(MediaRecord record) {
        repository.saveMedia(record);
    }

    private void validateUploadCreate(UploadCreateRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        requireText(request.ownerId(), "ownerId");
        normalizeFileName(request.fileName());
        normalizeChoice(request.contentType(), CONTENT_TYPES, "contentType");
        normalizeChoice(request.purpose(), PURPOSES, "purpose");
        normalizeBoundedLong(request.byteSize(), 1L, MAX_UPLOAD_BYTES, "byteSize");
    }

    private List<String> normalizeReferenceMediaIds(MediaReferenceBatchRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        List<String> mediaIds = normalizeUniqueStrings(request.mediaIds());
        if (mediaIds.isEmpty()) {
            throw new BadRequestException("mediaIds is required");
        }
        if (mediaIds.size() > MAX_REFERENCE_BATCH_SIZE) {
            throw new BadRequestException("mediaIds must contain 100 items or fewer");
        }
        return mediaIds;
    }

    private MediaMemorySnapshotSyncResponse buildMemorySnapshotSync(
            String consumerId,
            Long afterSequence,
            Integer limit) {
        String normalizedConsumerId = normalizeConsumerId(consumerId);
        long checkpointSequence = checkpointSequence(normalizedConsumerId);
        long normalizedAfterSequence = afterSequence == null
                ? checkpointSequence
                : normalizeAfterSequence(afterSequence);
        int normalizedLimit = normalizeBoundedInt(limit, DEFAULT_EVENT_LIMIT, 1, MAX_EVENT_LIMIT, "limit");
        List<MediaLifecycleEventRecord> records = repository.findLifecycleEventsAfter(
                normalizedAfterSequence,
                normalizedLimit + 1);
        boolean hasMore = records.size() > normalizedLimit;
        List<MediaLifecycleEventRecord> events = records.stream()
                .limit(normalizedLimit)
                .toList();
        long lastSequence = events.isEmpty()
                ? normalizedAfterSequence
                : events.getLast().sequence();
        List<MemoryMediaSnapshotBatchItem> snapshots = events.stream()
                .filter(event -> MEMORY_REFERENCE_PURPOSES.contains(event.purpose()))
                .map(this::toMemorySnapshotBatchItem)
                .toList();
        return new MediaMemorySnapshotSyncResponse(
                normalizedAfterSequence,
                lastSequence,
                hasMore,
                events.size(),
                snapshots.size(),
                normalizedConsumerId,
                checkpointSequence,
                new MemoryMediaSnapshotBatchRequest(snapshots));
    }

    private MediaMemorySnapshotSyncRunRecord toSyncRunRecord(
            String runId,
            MediaMemorySnapshotSyncResponse projection,
            boolean memoryCalled,
            String outcome,
            String errorMessage,
            Instant startedAt,
            Instant completedAt) {
        return new MediaMemorySnapshotSyncRunRecord(
                runId,
                projection.consumerId(),
                projection.afterSequence(),
                projection.lastSequence(),
                projection.hasMore(),
                projection.eventCount(),
                projection.snapshotCount(),
                memoryCalled,
                outcome,
                optionalTrim(errorMessage, ""),
                startedAt,
                completedAt);
    }

    private MediaMemorySnapshotSyncRunHistoryEntry toSyncRunHistoryEntry(
            MediaMemorySnapshotSyncRunRecord run) {
        return new MediaMemorySnapshotSyncRunHistoryEntry(
                run.runId(),
                run.consumerId(),
                run.afterSequence(),
                run.lastSequence(),
                run.hasMore(),
                run.eventCount(),
                run.snapshotCount(),
                run.memoryCalled(),
                run.outcome(),
                run.errorMessage(),
                run.startedAt(),
                run.completedAt(),
                durationMillis(run.startedAt(), run.completedAt()));
    }

    private MediaMemorySnapshotSyncRunHistorySummary syncRunHistorySummary(
            List<MediaMemorySnapshotSyncRunHistoryEntry> runs) {
        int succeededCount = 0;
        int noopCount = 0;
        int failedCount = 0;
        int memoryCalledCount = 0;
        int totalEventCount = 0;
        int totalSnapshotCount = 0;
        int consecutiveFailureCount = 0;
        long totalDurationMillis = 0L;
        long maxDurationMillis = 0L;
        int slowCount = 0;
        long slowThresholdMillis = syncPerformanceSlowThresholdMillis();
        boolean countingConsecutiveFailures = true;
        for (MediaMemorySnapshotSyncRunHistoryEntry run : runs) {
            if (SYNC_OUTCOME_SUCCEEDED.equals(run.outcome())) {
                succeededCount++;
            } else if (SYNC_OUTCOME_NOOP.equals(run.outcome())) {
                noopCount++;
            } else if (SYNC_OUTCOME_FAILED.equals(run.outcome())) {
                failedCount++;
            }
            if (run.memoryCalled()) {
                memoryCalledCount++;
            }
            totalEventCount += run.eventCount();
            totalSnapshotCount += run.snapshotCount();
            totalDurationMillis += run.durationMillis();
            maxDurationMillis = Math.max(maxDurationMillis, run.durationMillis());
            if (isSlowSyncDuration(run.durationMillis())) {
                slowCount++;
            }
            if (countingConsecutiveFailures && SYNC_OUTCOME_FAILED.equals(run.outcome())) {
                consecutiveFailureCount++;
            } else {
                countingConsecutiveFailures = false;
            }
        }
        MediaMemorySnapshotSyncRunHistoryEntry latest = runs.isEmpty()
                ? null
                : runs.getFirst();
        return new MediaMemorySnapshotSyncRunHistorySummary(
                succeededCount,
                noopCount,
                failedCount,
                memoryCalledCount,
                totalEventCount,
                totalSnapshotCount,
                consecutiveFailureCount,
                latest == null ? null : latest.runId(),
                latest == null ? null : latest.outcome(),
                latest == null ? null : latest.errorMessage(),
                latest == null ? null : latest.completedAt(),
                latest == null ? null : latest.durationMillis(),
                totalDurationMillis,
                runs.isEmpty() ? null : totalDurationMillis / runs.size(),
                runs.isEmpty() ? null : maxDurationMillis,
                slowThresholdMillis,
                slowCount,
                latest != null && isSlowSyncDuration(latest.durationMillis()),
                !runs.isEmpty() && isSlowSyncDuration(maxDurationMillis),
                performanceHealth(!runs.isEmpty(), slowCount));
    }

    private MediaMemorySnapshotSyncDispatchRecord toSyncDispatchRecord(
            MediaMemorySnapshotSyncDispatchResponse response) {
        MediaMemorySnapshotSyncRunHint recommendedRun = response.recommendedRun();
        MediaMemorySnapshotSyncRunResponse latestRun = response.run();
        return new MediaMemorySnapshotSyncDispatchRecord(
                response.dispatchId(),
                response.dispatched(),
                optionalTrim(response.skippedReason(), null),
                optionalTrim(response.stoppedReason(), null),
                recommendedRun == null ? null : recommendedRun.consumerId(),
                recommendedRun == null ? null : recommendedRun.path(),
                recommendedRun == null ? null : recommendedRun.afterSequence(),
                recommendedRun == null ? null : recommendedRun.limit(),
                latestRun == null ? null : latestRun.runId(),
                latestRun == null ? null : latestRun.consumerId(),
                latestRun == null ? null : latestRun.outcome(),
                latestRun == null ? null : latestRun.errorMessage(),
                response.requestedRunCount(),
                response.runCount(),
                response.checkedAt(),
                response.completedAt());
    }

    private MediaMemorySnapshotSyncDispatchHistoryEntry toSyncDispatchHistoryEntry(
            MediaMemorySnapshotSyncDispatchRecord dispatch) {
        return new MediaMemorySnapshotSyncDispatchHistoryEntry(
                dispatch.dispatchId(),
                dispatch.dispatched(),
                dispatch.skippedReason(),
                dispatch.stoppedReason(),
                syncDispatchOutcome(dispatch),
                dispatch.recommendedConsumerId(),
                dispatch.recommendedPath(),
                dispatch.recommendedAfterSequence(),
                dispatch.recommendedLimit(),
                dispatch.latestRunId(),
                dispatch.latestConsumerId(),
                dispatch.latestOutcome(),
                dispatch.latestErrorMessage(),
                dispatch.requestedRunCount(),
                dispatch.runCount(),
                dispatch.startedAt(),
                dispatch.completedAt(),
                durationMillis(dispatch.startedAt(), dispatch.completedAt()));
    }

    private MediaMemorySnapshotSyncDispatchHistorySummary syncDispatchHistorySummary(
            List<MediaMemorySnapshotSyncDispatchHistoryEntry> dispatches) {
        int completedCount = 0;
        int failedCount = 0;
        int skippedCount = 0;
        int dispatchInProgressSkippedCount = 0;
        int noRunnableCount = 0;
        int maxRunsReachedCount = 0;
        int totalRunCount = 0;
        long totalDurationMillis = 0L;
        long maxDurationMillis = 0L;
        int slowCount = 0;
        long slowThresholdMillis = syncPerformanceSlowThresholdMillis();
        for (MediaMemorySnapshotSyncDispatchHistoryEntry dispatch : dispatches) {
            if (DISPATCH_HISTORY_OUTCOME_COMPLETED.equals(dispatch.outcome())) {
                completedCount++;
            } else if (DISPATCH_HISTORY_OUTCOME_FAILED.equals(dispatch.outcome())) {
                failedCount++;
            } else if (DISPATCH_HISTORY_OUTCOME_SKIPPED.equals(dispatch.outcome())) {
                skippedCount++;
            }
            if (DISPATCH_SKIPPED_IN_PROGRESS.equals(dispatch.skippedReason())) {
                dispatchInProgressSkippedCount++;
            }
            if (DISPATCH_SKIPPED_NO_RUNNABLE_SYNC.equals(dispatch.stoppedReason())) {
                noRunnableCount++;
            }
            if (DISPATCH_STOPPED_MAX_RUNS_REACHED.equals(dispatch.stoppedReason())) {
                maxRunsReachedCount++;
            }
            totalRunCount += dispatch.runCount();
            totalDurationMillis += dispatch.durationMillis();
            maxDurationMillis = Math.max(maxDurationMillis, dispatch.durationMillis());
            if (isSlowSyncDuration(dispatch.durationMillis())) {
                slowCount++;
            }
        }
        MediaMemorySnapshotSyncDispatchHistoryEntry latest = dispatches.isEmpty()
                ? null
                : dispatches.getFirst();
        return new MediaMemorySnapshotSyncDispatchHistorySummary(
                completedCount,
                failedCount,
                skippedCount,
                dispatchInProgressSkippedCount,
                noRunnableCount,
                maxRunsReachedCount,
                totalRunCount,
                latest == null ? null : latest.dispatchId(),
                latest == null ? null : latest.outcome(),
                latest == null ? null : latest.stoppedReason(),
                latest == null ? null : latest.completedAt(),
                latest == null ? null : latest.durationMillis(),
                totalDurationMillis,
                dispatches.isEmpty() ? null : totalDurationMillis / dispatches.size(),
                dispatches.isEmpty() ? null : maxDurationMillis,
                slowThresholdMillis,
                slowCount,
                latest != null && isSlowSyncDuration(latest.durationMillis()),
                !dispatches.isEmpty() && isSlowSyncDuration(maxDurationMillis),
                performanceHealth(!dispatches.isEmpty(), slowCount));
    }

    private String syncDispatchOutcome(MediaMemorySnapshotSyncDispatchRecord dispatch) {
        if (!dispatch.dispatched()) {
            return DISPATCH_HISTORY_OUTCOME_SKIPPED;
        }
        if (DISPATCH_STOPPED_RUN_FAILED.equals(dispatch.stoppedReason())
                || SYNC_OUTCOME_FAILED.equals(dispatch.latestOutcome())) {
            return DISPATCH_HISTORY_OUTCOME_FAILED;
        }
        return DISPATCH_HISTORY_OUTCOME_COMPLETED;
    }

    private MediaSyncCheckpointResponse advanceMemorySnapshotCheckpoint(MediaSyncCheckpointRequest request) {
        if (request == null) {
            throw new BadRequestException("Request body is required");
        }
        String consumerId = normalizeConsumerId(request.consumerId());
        long lastSequence = normalizeCheckpointSequence(request.lastSequence());
        MediaSyncCheckpointRecord existing = syncOpsStore.findSyncCheckpoint(consumerId);
        long previousSequence = existing == null ? 0L : existing.lastSequence();
        if (lastSequence < previousSequence) {
            throw new WebApplicationException(
                    "lastSequence cannot move checkpoint backward",
                    Response.Status.CONFLICT);
        }
        if (existing != null && lastSequence == previousSequence) {
            return toCheckpointResponse(existing, previousSequence, false);
        }
        MediaSyncCheckpointRecord checkpoint = syncOpsStore.saveSyncCheckpoint(
                new MediaSyncCheckpointRecord(consumerId, lastSequence, Instant.now()));
        return toCheckpointResponse(checkpoint, previousSequence, lastSequence > previousSequence);
    }

    private long normalizeAfterSequence(Long value) {
        if (value == null) {
            return 0L;
        }
        if (value < 0L) {
            throw new BadRequestException("afterSequence must be greater than or equal to zero");
        }
        return value;
    }

    private String normalizeConsumerId(String value) {
        return optionalTextMaxLength(
                value,
                DEFAULT_MEMORY_SYNC_CONSUMER_ID,
                "consumerId",
                MAX_CONSUMER_ID_LENGTH);
    }

    private long checkpointSequence(String consumerId) {
        MediaSyncCheckpointRecord checkpoint = syncOpsStore.findSyncCheckpoint(consumerId);
        return checkpoint == null ? 0L : checkpoint.lastSequence();
    }

    private long normalizeCheckpointSequence(Long value) {
        if (value == null) {
            throw new BadRequestException("lastSequence is required");
        }
        if (value < 0L) {
            throw new BadRequestException("lastSequence must be greater than or equal to zero");
        }
        return value;
    }

    private MediaSyncCheckpointResponse toCheckpointResponse(String consumerId) {
        MediaSyncCheckpointRecord checkpoint = syncOpsStore.findSyncCheckpoint(consumerId);
        if (checkpoint == null) {
            return new MediaSyncCheckpointResponse(consumerId, 0L, 0L, false, null);
        }
        return toCheckpointResponse(checkpoint, checkpoint.lastSequence(), false);
    }

    private MediaSyncCheckpointResponse toCheckpointResponse(
            MediaSyncCheckpointRecord checkpoint,
            long previousSequence,
            boolean advanced) {
        return new MediaSyncCheckpointResponse(
                checkpoint.consumerId(),
                previousSequence,
                checkpoint.lastSequence(),
                advanced,
                checkpoint.updatedAt());
    }

    private MediaRecord requireActiveMedia(String mediaId) {
        MediaRecord record = requireMedia(mediaId);
        if (!STATUS_ACTIVE.equals(record.status())) {
            throw new NotFoundException("Media not found: " + mediaId);
        }
        return record;
    }

    private MediaRecord requireMedia(String mediaId) {
        MediaRecord record = repository.findMediaById(requireText(mediaId, "mediaId"));
        if (record == null || STATUS_DELETED.equals(record.status())) {
            throw new NotFoundException("Media not found: " + mediaId);
        }
        return record;
    }

    private String statusForModeration(String moderationStatus) {
        if (MODERATION_REJECTED.equals(moderationStatus)) {
            return STATUS_REJECTED;
        }
        return STATUS_ACTIVE;
    }

    private String normalizeModerationReason(String value) {
        return optionalTextMaxLength(value, "", "reason", MAX_MODERATION_REASON_LENGTH);
    }

    private UploadResponse toUploadResponse(UploadRecord upload) {
        return new UploadResponse(
                upload.uploadId(),
                upload.ownerId(),
                upload.fileName(),
                upload.contentType(),
                upload.byteSize(),
                upload.checksumSha256(),
                upload.purpose(),
                upload.tags(),
                upload.uploadUrl(),
                upload.mediaUrl(),
                upload.status(),
                upload.moderationStatus(),
                upload.expiresAt(),
                upload.createdAt(),
                upload.updatedAt());
    }

    private MediaResponse toMediaResponse(MediaRecord record) {
        return new MediaResponse(
                record.mediaId(),
                record.ownerId(),
                record.fileName(),
                record.contentType(),
                record.byteSize(),
                record.checksumSha256(),
                record.purpose(),
                record.tags(),
                record.mediaUrl(),
                record.status(),
                record.moderationStatus(),
                record.createdAt(),
                record.updatedAt());
    }

    private MediaReferenceResponse toMediaReferenceResponse(MediaRecord record) {
        boolean memoryAttachable = memoryAttachable(record);
        return new MediaReferenceResponse(
                record.mediaId(),
                record.ownerId(),
                record.mediaUrl(),
                thumbnailUrl(record),
                record.status(),
                record.moderationStatus(),
                record.purpose(),
                record.contentType(),
                memoryAttachable,
                memoryAttachable && MODERATION_APPROVED.equals(record.moderationStatus()),
                record.updatedAt());
    }

    private void emitLifecycleEvent(String action, MediaRecord record, Instant createdAt) {
        repository.saveLifecycleEvent(new MediaLifecycleEventRecord(
                repository.nextLifecycleSequence(),
                "media_event_" + UUID.randomUUID(),
                action,
                record.mediaId(),
                record.ownerId(),
                record.status(),
                record.moderationStatus(),
                record.purpose(),
                record.mediaUrl(),
                memoryAttachable(record),
                publicMemoryEligible(record),
                createdAt));
    }

    private MediaLifecycleEventResponse toLifecycleEventResponse(MediaLifecycleEventRecord event) {
        return new MediaLifecycleEventResponse(
                event.sequence(),
                event.eventId(),
                event.action(),
                event.mediaId(),
                event.ownerId(),
                event.mediaStatus(),
                event.moderationStatus(),
                event.purpose(),
                event.mediaUrl(),
                event.memoryAttachable(),
                event.publicMemoryEligible(),
                event.createdAt());
    }

    private MemoryMediaSnapshotBatchItem toMemorySnapshotBatchItem(MediaLifecycleEventRecord event) {
        return new MemoryMediaSnapshotBatchItem(
                event.mediaId(),
                event.mediaStatus(),
                event.moderationStatus(),
                event.sequence(),
                event.eventId(),
                event.action());
    }

    private boolean memoryAttachable(MediaRecord record) {
        return STATUS_ACTIVE.equals(record.status()) && MEMORY_REFERENCE_PURPOSES.contains(record.purpose());
    }

    private boolean publicMemoryEligible(MediaRecord record) {
        return memoryAttachable(record) && MODERATION_APPROVED.equals(record.moderationStatus());
    }

    private String thumbnailUrl(MediaRecord record) {
        return record.mediaUrl();
    }

    private ModerationEventResponse toModerationEventResponse(MediaModerationEvent event) {
        return new ModerationEventResponse(
                event.eventId(),
                event.mediaId(),
                event.reviewerId(),
                event.moderationStatus(),
                event.previousStatus(),
                event.nextStatus(),
                event.reason(),
                event.createdAt());
    }

    private String normalizeChoice(String value, Set<String> allowed, String field) {
        return requireChoice(value, allowed, field);
    }

    private String normalizeFileName(String value) {
        String normalized = requireText(value, "fileName")
                .replace('\\', '/');
        int slash = normalized.lastIndexOf('/');
        if (slash >= 0) {
            normalized = normalized.substring(slash + 1);
        }
        normalized = normalized.replaceAll("[^A-Za-z0-9._-]", "_");
        if (normalized.isBlank() || ".".equals(normalized) || "..".equals(normalized)) {
            throw new BadRequestException("fileName is required");
        }
        return normalized;
    }

    private List<String> normalizeTags(List<String> tags) {
        return normalizeUniqueStrings(tags);
    }

}
