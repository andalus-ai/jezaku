package tech.kayys.jezaku.memory;

import jakarta.enterprise.context.ApplicationScoped;

import java.util.Map;

@ApplicationScoped
public class SeedMemoryMediaResolver implements MemoryMediaResolver {
    private final Map<String, MemoryMediaReference> media = Map.of(
            "media_seed_courtyard",
            new MemoryMediaReference(
                    "media_seed_courtyard",
                    "user_current",
                    "https://cdn.jezaku.local/media/seed/courtyard.jpg",
                    "https://cdn.jezaku.local/memories/courtyard-thumb.jpg",
                    "active",
                    "approved",
                    "memory_photo"),
            "media_seed_rooftop",
                new MemoryMediaReference(
                        "media_seed_rooftop",
                        "user_rooftop",
                        "https://cdn.jezaku.local/media/seed/rooftop.webp",
                        "https://cdn.jezaku.local/memories/rooftop-thumb.jpg",
                        "active",
                        "approved",
                        "memory_photo"),
                "media_seed_reviewed",
                new MemoryMediaReference(
                        "media_seed_reviewed",
                        "user_reviewed",
                        "https://cdn.jezaku.local/media/seed/reviewed.jpg",
                        "https://cdn.jezaku.local/memories/reviewed-thumb.jpg",
                        "active",
                        "approved",
                        "memory_photo"),
                "media_seed_stale_guard",
                new MemoryMediaReference(
                        "media_seed_stale_guard",
                        "user_stale_guard",
                        "https://cdn.jezaku.local/media/seed/stale-guard.jpg",
                        "https://cdn.jezaku.local/memories/stale-guard-thumb.jpg",
                        "active",
                        "approved",
                        "memory_photo"),
                "media_seed_pending",
                new MemoryMediaReference(
                    "media_seed_pending",
                    "user_current",
                    "https://cdn.jezaku.local/media/seed/fresh-marker.png",
                    "https://cdn.jezaku.local/media/seed/fresh-marker.png",
                    "active",
                    "pending",
                    "anchor_media"));

    @Override
    public MemoryMediaReference resolve(String mediaId) {
        return media.get(mediaId);
    }
}
