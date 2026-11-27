package tech.kayys.jezaku.extensions.validation;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class ExtensionManifestValidatorTest {
    private ExtensionManifestValidator validator;

    @BeforeEach
    void setUp() {
        validator = new ExtensionManifestValidator();
        validator.mapper = new ObjectMapper();
        validator.capabilities = new ExtensionCapabilityCatalog();
    }

    @Test
    void acceptsKnownCapabilityAndScopedPermission() {
        var result = validator.validate(validManifest());
        assertTrue(result.valid(), () -> result.violations().toString());
    }

    @Test
    void rejectsUnknownCapabilityEvenWhenManifestIsOtherwiseValid() {
        var result = validator.validate(validManifest().replace("spatial.object.read", "system.root"));
        assertFalse(result.valid());
        assertTrue(result.violations().stream().anyMatch(v -> v.contains("unknown capability")));
    }

    @Test
    void rejectsPermissionNotDeclaredAsCapability() {
        var result = validator.validate(validManifest().replace(
                "\"id\":\"spatial.object.read\",\"access\":\"read\"",
                "\"id\":\"commerce.payment.capture\",\"access\":\"invoke\""));
        assertFalse(result.valid());
        assertTrue(result.violations().stream().anyMatch(v -> v.contains("must correspond")));
    }

    @Test
    void rejectsUnsupportedScopeAndImpact() {
        var result = validator.validate(validManifest().replace("\"type\":\"owned\"", "\"type\":\"global\"")
                .replace("\"physicalWorldImpact\":\"none\"", "\"physicalWorldImpact\":\"actuate-anything\""));
        assertFalse(result.valid());
        assertTrue(result.violations().stream().anyMatch(v -> v.contains("scope.type")));
        assertTrue(result.violations().stream().anyMatch(v -> v.contains("physicalWorldImpact")));
    }

    @Test
    void rejectsMalformedJson() {
        assertFalse(validator.validate("{not-json").valid());
    }

    private String validManifest() {
        return """
                {
                  "manifestVersion":"1.0.0",
                  "id":"demo.weather",
                  "version":"1.2.3",
                  "publisher":{"id":"publisher.demo","displayName":"Demo Publisher"},
                  "compatibility":{"jezakuApi":"1.x"},
                  "packageType":"declarative-object",
                  "capabilities":[{"id":"spatial.object.read","rationale":"Render nearby public objects"}],
                  "permissions":[{"id":"spatial.object.read","access":"read","scope":{"type":"owned"},"purpose":"Display public objects"}],
                  "assets":[],
                  "privacy":{"dataCollected":[],"dataShared":[],"retention":"No data retained"},
                  "safety":{"contentCategories":["informational"],"physicalWorldImpact":"none"}
                }
                """;
    }
}
