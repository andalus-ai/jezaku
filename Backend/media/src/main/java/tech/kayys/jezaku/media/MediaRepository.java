package tech.kayys.jezaku.media;

import java.util.List;

public interface MediaRepository {
    void saveUpload(UploadRecord upload);

    UploadRecord findUploadById(String uploadId);

    void saveMedia(MediaRecord media);

    MediaRecord findMediaById(String mediaId);

    List<MediaRecord> findAllMedia();

    void saveModerationEvent(MediaModerationEvent event);

    List<MediaModerationEvent> findModerationEventsByMediaId(String mediaId);

    MediaLifecycleEventRecord saveLifecycleEvent(MediaLifecycleEventRecord event);

    long nextLifecycleSequence();

    long latestLifecycleSequence();

    List<MediaLifecycleEventRecord> findLifecycleEventsAfter(long sequence, int limit);
}
