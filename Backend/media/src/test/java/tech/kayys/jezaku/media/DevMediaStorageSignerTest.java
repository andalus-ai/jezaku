package tech.kayys.jezaku.media;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DevMediaStorageSignerTest {
    @Test
    void signsUploadAndMediaUrlsForDevelopmentStorage() {
        DevMediaStorageSigner signer = new DevMediaStorageSigner(
                "https://upload.jezaku.local/uploads/",
                "https://cdn.jezaku.local/media/",
                "dev-");

        MediaStorageUrls urls = signer.signUpload("upload_123", "owner 123", "memory_photo", "camera capture.jpg");

        assertEquals("memory_photo/owner_123/upload_123/camera_capture.jpg", urls.objectKey());
        assertTrue(urls.uploadUrl().startsWith("https://upload.jezaku.local/uploads/upload_123?token=dev-"));
        assertEquals("https://cdn.jezaku.local/media/upload_123/camera+capture.jpg", urls.mediaUrl());
    }

    @Test
    void usesConfiguredBaseUrlsAndTokenPrefix() {
        DevMediaStorageSigner signer = new DevMediaStorageSigner(
                "https://uploads.example.test/root/",
                "https://cdn.example.test/assets/",
                "unit token ");

        MediaStorageUrls urls = signer.signUpload("upload_custom", "owner_custom", "anchor_media", "wall.png");

        assertEquals("anchor_media/owner_custom/upload_custom/wall.png", urls.objectKey());
        assertTrue(urls.uploadUrl().startsWith(
                "https://uploads.example.test/root/upload_custom?token=unit+token"));
        assertEquals("https://cdn.example.test/assets/upload_custom/wall.png", urls.mediaUrl());
    }
}
