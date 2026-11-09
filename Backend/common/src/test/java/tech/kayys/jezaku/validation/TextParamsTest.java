package tech.kayys.jezaku.validation;

import jakarta.ws.rs.BadRequestException;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static tech.kayys.jezaku.validation.TextParams.normalizeUniqueStrings;
import static tech.kayys.jezaku.validation.TextParams.optionalChoice;
import static tech.kayys.jezaku.validation.TextParams.optionalTextMaxLength;
import static tech.kayys.jezaku.validation.TextParams.optionalTrim;
import static tech.kayys.jezaku.validation.TextParams.requireChoice;
import static tech.kayys.jezaku.validation.TextParams.requireText;
import static tech.kayys.jezaku.validation.TextParams.requireTextMaxLength;

class TextParamsTest {
    @Test
    void trimsOptionalTextOrUsesDefault() {
        assertEquals("fallback", optionalTrim(null, "fallback"));
        assertEquals("fallback", optionalTrim("   ", "fallback"));
        assertEquals("hello", optionalTrim(" hello ", "fallback"));
    }

    @Test
    void requiresNonBlankText() {
        assertEquals("user_current", requireText(" user_current ", "userId"));
        assertThrows(BadRequestException.class, () -> requireText(" ", "userId"));
    }

    @Test
    void boundsRequiredAndOptionalTextLength() {
        assertEquals("hello", requireTextMaxLength(" hello ", "body", 5));
        assertEquals("", optionalTextMaxLength(null, "", "statusMessage", 140));
        assertEquals("fallback", optionalTextMaxLength("   ", "fallback", "statusMessage", 140));

        BadRequestException error = assertThrows(BadRequestException.class,
                () -> requireTextMaxLength("abcdef", "body", 5));
        assertEquals("body must be 5 characters or fewer", error.getMessage());
        assertThrows(BadRequestException.class,
                () -> optionalTextMaxLength("abcdef", "", "statusMessage", 5));
    }

    @Test
    void requiresAllowedChoices() {
        assertEquals("trail", requireChoice(" Trail ", Set.of("trail", "photo"), "category"));
        assertThrows(BadRequestException.class, () -> requireChoice("other", Set.of("trail"), "category"));
    }

    @Test
    void supportsCustomChoiceMessagesAndDefaults() {
        BadRequestException error = assertThrows(BadRequestException.class,
                () -> requireChoice("daily", Set.of("global", "weekly"), "scope", "scope must be global or weekly"));
        assertEquals("scope must be global or weekly", error.getMessage());

        assertEquals("public", optionalChoice(null, "public", Set.of("public", "friends"), "visibility",
                "visibility must be public or friends"));
        assertEquals("friends", optionalChoice(" Friends ", "public", Set.of("public", "friends"), "visibility",
                "visibility must be public or friends"));
    }

    @Test
    void normalizesUniqueStringsInInputOrder() {
        assertEquals(List.of("trail", "camera"), normalizeUniqueStrings(List.of(" trail ", "", "camera", "trail")));
        assertEquals(List.of(), normalizeUniqueStrings(null));
    }

    @Test
    void canUseDefaultListForNullValues() {
        assertEquals(List.of("existing"), normalizeUniqueStrings(null, List.of("existing")));
        assertEquals(List.of(), normalizeUniqueStrings(List.of("   "), List.of("existing")));
    }
}
