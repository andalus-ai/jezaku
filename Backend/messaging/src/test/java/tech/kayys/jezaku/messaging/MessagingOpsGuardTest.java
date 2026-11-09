package tech.kayys.jezaku.messaging;

import jakarta.ws.rs.ForbiddenException;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertThrows;

class MessagingOpsGuardTest {
    @Test
    void allowsOpsAccessWhenTokenIsNotConfigured() {
        MessagingOpsGuard guard = guard(Optional.empty());

        guard.requireAccess(null);
        guard.requireAccess("anything");
    }

    @Test
    void allowsOpsAccessWhenConfiguredTokenMatches() {
        MessagingOpsGuard guard = guard(Optional.of(" secret "));

        guard.requireAccess("secret");
        guard.requireAccess(" secret ");
    }

    @Test
    void rejectsOpsAccessWhenConfiguredTokenIsMissingOrWrong() {
        MessagingOpsGuard guard = guard(Optional.of("secret"));

        assertThrows(ForbiddenException.class, () -> guard.requireAccess(null));
        assertThrows(ForbiddenException.class, () -> guard.requireAccess(""));
        assertThrows(ForbiddenException.class, () -> guard.requireAccess("wrong"));
    }

    @Test
    void treatsBlankConfiguredTokenAsOpenForLocalDevelopment() {
        MessagingOpsGuard guard = guard(Optional.of("   "));

        guard.requireAccess(null);
    }

    private MessagingOpsGuard guard(Optional<String> token) {
        MessagingOpsGuard guard = new MessagingOpsGuard();
        guard.opsToken = token;
        return guard;
    }
}
