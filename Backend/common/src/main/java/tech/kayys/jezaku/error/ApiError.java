package tech.kayys.jezaku.error;

import java.time.Instant;

public record ApiError(String code, String message, int status, String path, String requestId, Instant timestamp) {
}
