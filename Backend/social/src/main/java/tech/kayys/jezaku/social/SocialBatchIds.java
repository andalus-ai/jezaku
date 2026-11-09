package tech.kayys.jezaku.social;

import jakarta.ws.rs.BadRequestException;

import java.util.LinkedHashSet;
import java.util.List;

import static tech.kayys.jezaku.validation.TextParams.requireText;

final class SocialBatchIds {
    private SocialBatchIds() {
    }

    static List<String> normalize(List<String> ids, String fieldName, int maxSize, String itemLabel) {
        if (ids == null || ids.isEmpty()) {
            throw new BadRequestException(fieldName + " is required");
        }
        if (ids.size() > maxSize) {
            throw new BadRequestException(fieldName + " may contain at most " + maxSize + " " + itemLabel);
        }
        LinkedHashSet<String> normalized = new LinkedHashSet<>();
        for (String id : ids) {
            normalized.add(requireText(id, fieldName));
        }
        return List.copyOf(normalized);
    }
}
