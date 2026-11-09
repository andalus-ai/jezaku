package tech.kayys.jezaku.camera;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionCreateRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEndRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventListResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionEventResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionHeartbeatRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionPauseRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResponse;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionResumeRequest;
import tech.kayys.jezaku.camera.CameraDtos.CameraSessionUpdateRequest;

import java.time.Instant;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CameraLiveSessionServiceTest {
    private static final Instant NOW = Instant.parse("2026-05-31T00:00:00Z");

    @Test
    void activeSessionsExcludeExpiredPausedAndEndedSessions() {
        CameraLiveSessionService service = new CameraLiveSessionService();

        CameraSessionRecord live = service.createAt(NOW, create("live_session_user"));
        CameraSessionRecord paused = service.createAt(NOW, create("paused_session_user"));
        CameraSessionRecord ended = service.createAt(NOW, create("ended_session_user"));
        service.updateAt(paused.sessionId(), updateStatus("paused"), NOW.plusSeconds(1));
        service.updateAt(ended.sessionId(), updateStatus("ended"), NOW.plusSeconds(1));

        List<CameraSessionRecord> active = service.activeSessions(NOW.plusSeconds(10));
        assertEquals(1, active.size());
        assertEquals(live.sessionId(), active.getFirst().sessionId());
        assertTrue(live.activeAt(NOW.plusSeconds(10)));
        assertFalse(live.activeAt(NOW.plusSeconds(181)));
    }

    @Test
    void updateRefreshesTelemetryAndVisibility() {
        CameraLiveSessionService service = new CameraLiveSessionService();
        CameraSessionRecord created = service.createAt(NOW, create("refresh_session_user"));

        CameraSessionRecord updated = service.updateAt(
                created.sessionId(),
                new CameraSessionUpdateRequest(
                        -6.890650,
                        107.610990,
                        746.25,
                        361.0,
                        92.0,
                        1.2,
                        80.0,
                        90.0,
                        "friends",
                        "live",
                        "Fresh ping",
                        240L),
                NOW.plusSeconds(30));

        assertEquals(created.sessionId(), updated.sessionId());
        assertEquals("friends", updated.visibility());
        assertEquals(1.0, updated.headingDegrees());
        assertEquals(92.0, updated.compassDegrees());
        assertEquals(1.2, updated.speedMetersPerSecond());
        assertEquals(90.0, updated.shareRadiusMeters());
        assertEquals("Fresh ping", updated.statusMessage());
        assertEquals(NOW.plusSeconds(270), updated.expiresAt());

        CameraSessionEventListResponse events = service.eventsAt(created.sessionId(), 10, null, NOW.plusSeconds(31));
        assertEquals(3, events.count());
        assertFalse(events.hasMore());
        assertEquals("session.created", events.events().getFirst().type());
        assertEquals("telemetry.updated", events.events().get(1).type());
        assertEquals("Fresh ping", events.events().get(1).statusMessage());
        assertEquals(92.0, events.events().get(1).compassDegrees());
        assertEquals("visibility.changed", events.events().get(2).type());
        assertEquals("friends", events.events().get(2).visibility());
        assertTrue(events.events().getFirst().sequence() < events.events().get(1).sequence());
        assertTrue(events.events().get(1).sequence() < events.events().get(2).sequence());
        assertEquals(events.events().get(2).sequence(), events.lastSequence());

        CameraSessionEventListResponse cursorEvents = service.eventsAt(
                created.sessionId(),
                10,
                events.events().getFirst().sequence(),
                NOW.plusSeconds(32));
        assertEquals(2, cursorEvents.count());
        assertEquals("telemetry.updated", cursorEvents.events().getFirst().type());
        assertEquals("visibility.changed", cursorEvents.events().get(1).type());
        assertFalse(cursorEvents.hasMore());
    }

    @Test
    void sessionEventsAreLimitedToMostRecentChronologicalEvents() {
        CameraLiveSessionService service = new CameraLiveSessionService();
        CameraSessionRecord created = service.createAt(NOW, create("limited_event_session_user"));
        service.updateAt(created.sessionId(), updateStatus("paused"), NOW.plusSeconds(1));
        service.updateAt(created.sessionId(), updateStatus("ended"), NOW.plusSeconds(2));

        CameraSessionEventListResponse events = service.eventsAt(created.sessionId(), 2, null, NOW.plusSeconds(3));
        assertEquals(2, events.count());
        assertTrue(events.hasMore());
        assertEquals("status.changed", events.events().getFirst().type());
        assertEquals("session.ended", events.events().get(1).type());
    }

    @Test
    void heartbeatRefreshesLiveSessionExpiryAndRecordsEvent() {
        CameraLiveSessionService service = new CameraLiveSessionService();
        CameraSessionRecord created = service.createAt(NOW, create("heartbeat_session_user"));

        CameraSessionRecord heartbeat = service.heartbeatAt(
                created.sessionId(),
                new CameraSessionHeartbeatRequest(240L),
                NOW.plusSeconds(60));

        assertEquals(created.sessionId(), heartbeat.sessionId());
        assertEquals(created.position(), heartbeat.position());
        assertEquals(created.compassDegrees(), heartbeat.compassDegrees());
        assertEquals(NOW.plusSeconds(60), heartbeat.updatedAt());
        assertEquals(NOW.plusSeconds(300), heartbeat.expiresAt());

        CameraSessionEventListResponse events = service.eventsAt(created.sessionId(), 10, null, NOW.plusSeconds(61));
        assertEquals(2, events.count());
        assertEquals("session.created", events.events().getFirst().type());
        assertEquals("session.heartbeat", events.events().get(1).type());
    }

    @Test
    void sessionResponseIncludesLifecycleGuidance() {
        CameraLiveSessionService service = new CameraLiveSessionService();
        CameraSessionRecord created = service.createAt(NOW, create("guidance_session_user"));

        CameraSessionResponse response = service.response(created, NOW.plusSeconds(30));

        assertEquals(created.sessionId(), response.sessionId());
        assertEquals(150, response.guidance().expiresInSeconds());
        assertEquals(30, response.guidance().telemetryAgeSeconds());
        assertEquals(60, response.guidance().heartbeatAfterSeconds());
        assertEquals(5, response.guidance().positionUpdateAfterSeconds());
        assertTrue(response.guidance().canHeartbeat());
        assertTrue(response.guidance().canPause());
        assertFalse(response.guidance().canResume());
        assertTrue(response.guidance().canEnd());
        assertEquals("live_active", response.guidance().reason());
    }

    @Test
    void streamReceivesLiveEventsAfterCursor() throws InterruptedException {
        CameraLiveSessionService service = new CameraLiveSessionService();
        CameraSessionRecord created = service.createAt(NOW, create("stream_session_user"));
        CameraSessionEventListResponse initial = service.eventsAt(created.sessionId(), 10, null, NOW.plusSeconds(1));
        CountDownLatch latch = new CountDownLatch(1);
        List<CameraSessionEventResponse> streamed = new CopyOnWriteArrayList<>();

        var subscription = service.streamEvents(created.sessionId(), 1, initial.lastSequence())
                .subscribe().with(event -> {
                    streamed.add(event);
                    latch.countDown();
                });

        service.heartbeatAt(created.sessionId(), new CameraSessionHeartbeatRequest(240L), NOW.plusSeconds(10));

        assertTrue(latch.await(1, TimeUnit.SECONDS));
        subscription.cancel();
        assertEquals(1, streamed.size());
        assertEquals("session.heartbeat", streamed.getFirst().type());
        assertEquals(created.sessionId(), streamed.getFirst().sessionId());
        assertTrue(streamed.getFirst().sequence() > initial.lastSequence());
    }

    @Test
    void streamReplaysEventsAfterCursorAndCompletesAtMaxEvents() {
        CameraLiveSessionService service = new CameraLiveSessionService();
        CameraSessionRecord created = service.createAt(NOW, create("stream_replay_session_user"));
        service.updateAt(created.sessionId(), new CameraSessionUpdateRequest(
                -6.890650,
                107.610990,
                null,
                null,
                92.0,
                null,
                null,
                null,
                null,
                null,
                "Stream replay",
                null), NOW.plusSeconds(10));

        List<CameraSessionEventResponse> streamed = service.streamEvents(created.sessionId(), 2, 0L)
                .collect().asList()
                .await().indefinitely();

        assertEquals(2, streamed.size());
        assertEquals("session.created", streamed.getFirst().type());
        assertEquals("telemetry.updated", streamed.get(1).type());
    }

    @Test
    void pauseAndResumeMoveSessionInAndOutOfActiveSet() {
        CameraLiveSessionService service = new CameraLiveSessionService();
        CameraSessionRecord created = service.createAt(NOW, create("pause_resume_session_user"));

        CameraSessionRecord paused = service.pauseAt(
                created.sessionId(),
                new CameraSessionPauseRequest("Camera backgrounded", 240L),
                NOW.plusSeconds(10));

        assertEquals("paused", paused.status());
        assertFalse(paused.activeAt(NOW.plusSeconds(11)));
        assertEquals("Camera backgrounded", paused.statusMessage());
        assertEquals(NOW.plusSeconds(250), paused.expiresAt());
        assertTrue(service.activeSessions(NOW.plusSeconds(11)).isEmpty());

        service.pauseAt(created.sessionId(), new CameraSessionPauseRequest("Duplicate pause", 240L),
                NOW.plusSeconds(11));

        CameraSessionRecord resumed = service.resumeAt(
                created.sessionId(),
                new CameraSessionResumeRequest("Camera foregrounded", 300L),
                NOW.plusSeconds(20));

        assertEquals("live", resumed.status());
        assertTrue(resumed.activeAt(NOW.plusSeconds(21)));
        assertEquals("Camera foregrounded", resumed.statusMessage());
        assertEquals(NOW.plusSeconds(320), resumed.expiresAt());
        assertEquals(1, service.activeSessions(NOW.plusSeconds(21)).size());

        CameraSessionEventListResponse events = service.eventsAt(created.sessionId(), 10, null, NOW.plusSeconds(22));
        assertEquals(5, events.count());
        assertEquals("session.created", events.events().getFirst().type());
        assertEquals("status.changed", events.events().get(1).type());
        assertEquals("session.paused", events.events().get(2).type());
        assertEquals("status.changed", events.events().get(3).type());
        assertEquals("session.resumed", events.events().get(4).type());
    }

    @Test
    void endMarksSessionInactiveAndDoesNotDuplicateEndEvents() {
        CameraLiveSessionService service = new CameraLiveSessionService();
        CameraSessionRecord created = service.createAt(NOW, create("end_session_user"));

        CameraSessionRecord ended = service.endAt(
                created.sessionId(),
                new CameraSessionEndRequest("Camera closed"),
                NOW.plusSeconds(20));

        assertEquals(created.sessionId(), ended.sessionId());
        assertEquals("ended", ended.status());
        assertFalse(ended.activeAt(NOW.plusSeconds(21)));
        assertEquals("Camera closed", ended.statusMessage());
        assertEquals(NOW.plusSeconds(20), ended.updatedAt());
        assertEquals(NOW.plusSeconds(20), ended.expiresAt());

        service.endAt(created.sessionId(), new CameraSessionEndRequest("Duplicate close"), NOW.plusSeconds(21));

        CameraSessionEventListResponse events = service.eventsAt(created.sessionId(), 10, null, NOW.plusSeconds(22));
        assertEquals(3, events.count());
        assertEquals("session.created", events.events().getFirst().type());
        assertEquals("status.changed", events.events().get(1).type());
        assertEquals("session.ended", events.events().get(2).type());
        assertEquals("Camera closed", events.events().get(2).statusMessage());
    }

    private CameraSessionCreateRequest create(String viewerId) {
        return new CameraSessionCreateRequest(
                viewerId,
                -6.890620,
                107.610790,
                742.0,
                42.0,
                42.0,
                0.4,
                100.0,
                100.0,
                "public",
                "Live",
                180L);
    }

    private CameraSessionUpdateRequest updateStatus(String status) {
        return new CameraSessionUpdateRequest(
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                status,
                null,
                null);
    }
}
