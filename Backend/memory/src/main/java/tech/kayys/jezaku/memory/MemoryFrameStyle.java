package tech.kayys.jezaku.memory;

import jakarta.ws.rs.BadRequestException;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * The look an owner gave a frame, as an opaque id such as {@code oak} or {@code gold}.
 *
 * <p>The service stores and returns the id and does not know the catalog: clients own what each look
 * means, and an id they do not recognise falls back to their default look. Keeping the check to the id's
 * shape lets new looks (including extension-provided ones) ship without a backend deploy while still
 * keeping arbitrary text out of the field.
 */
final class MemoryFrameStyle {
    static final int MAX_LENGTH = 64;

    private static final Pattern SHAPE = Pattern.compile("[a-z0-9][a-z0-9._-]*");

    private MemoryFrameStyle() {
    }

    /**
     * The normalised id (trimmed, lower case), or {@code null} when none was sent, which clients render with
     * their default look.
     *
     * @throws BadRequestException when the value is not a valid id
     */
    static String normalize(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String id = raw.trim().toLowerCase(Locale.ROOT);
        if (id.length() > MAX_LENGTH || !SHAPE.matcher(id).matches()) {
            throw new BadRequestException(
                    "frameStyle must be 1-" + MAX_LENGTH
                            + " characters: lower-case letters, digits, '.', '_' or '-', starting with a letter or digit");
        }
        return id;
    }
}
