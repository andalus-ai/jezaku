package tech.kayys.jezaku.extensions.validation;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.networknt.schema.JsonSchemaFactory;
import com.networknt.schema.SpecVersion;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.InputStream;

import static org.junit.jupiter.api.Assertions.*;

class ExtensionManifestValidatorTest {
    private ExtensionManifestValidator validator;

    @BeforeEach
    void setUp() throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        try (InputStream schemaStream = getClass().getResourceAsStream("/schemas/jezaku-extension-manifest.schema.json")) {
            assertNotNull(schemaStream, "manifest schema must be packaged as a module resource");
            var schemaNode = mapper.readTree(schemaStream);
            var schema = JsonSchemaFactory.getInstance(SpecVersion.VersionFlag.V202012).getSchema(schemaNode);
            validator = new ExtensionManifestValidator(mapper, new ExtensionCapabilityCatalog(), schema);
        }
    }

    @Test
    void acceptsSchemaValidKnownCapabilityAndScopedPermission() {
        var result = validator.validate(validManifest());
        assertTrue(result.valid(), () -> result.violations().toString());
        assertTrue(result.highRiskCapabilities().isEmpty());
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
    void rejectsUnknownPropertiesAndInvalidNestedAssetMetadataThroughSchema() {
        String invalid = validManifest().replace("\"assets\":[]",
                "\"assets\":[{\"path\":\"../escape.bin\",\"mediaType\":\"application/octet-stream\","
                        + "\"sha256\":\"bad\",\"license\":\"MIT\",\"unexpected\":true}]")
                .replace("\"packageType\":\"declarative-object\"",
                        "\"packageType\":\"declarative-object\",\"unexpectedRootField\":true");
        var result = validator.validate(invalid);
        assertFalse(result.valid());
        assertTrue(result.violations().stream().anyMatch(v -> v.startsWith("schema:")));
    }

    @Test
    void reportsHighRiskCapabilitiesWithoutGrantingThem() {
        String manifest = validManifest()
                .replace("\"spatial.object.read\",\"rationale\"",
                        "\"spatial.location.precise\",\"rationale\"")
                .replace("\"spatial.object.read\",\"access\"",
                        "\"spatial.location.precise\",\"access\"");
        var result = validator.validate(manifest);
        assertTrue(result.valid(), () -> result.violations().toString());
        assertEquals(java.util.List.of("spatial.location.precise"), result.highRiskCapabilities());
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
    void rejectsTrailingJsonTokens() {
        assertFalse(validator.validate(validManifest() + "{}").valid());
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
