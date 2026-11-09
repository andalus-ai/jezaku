package tech.kayys.jezaku.media;

public interface MediaStorageSigner {
    MediaStorageUrls signUpload(String uploadId, String ownerId, String purpose, String fileName);
}
