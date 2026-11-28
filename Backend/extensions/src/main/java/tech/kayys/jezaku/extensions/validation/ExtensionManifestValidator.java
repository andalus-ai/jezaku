package tech.kayys.jezaku.extensions.validation;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.networknt.schema.JsonSchema;
import com.networknt.schema.ValidationMessage;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Pattern;

/**
 * Validates manifest v1.0.0 against the checked-in JSON Schema and backend
 * capability policy. Validation never creates grants or marks a package approved.
 */
public class ExtensionManifestValidator {
    private static final Pattern IDENTIFIER = Pattern.compile("^[a-z0-9][a-z0-9.-]{2,127}$");
    private static final Pattern SEMVER = Pattern.compile(
            "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\\+[0-9A-Za-z.-]+)?$");
    private static final Set<String> PACKAGE_TYPES = Set.of(
            "declarative-object", "asset-pack", "experience", "provider-adapter", "integration", "sandboxed-module");
    private static final Set<String> ACCESS = Set.of("read", "create", "update", "delete", "invoke");
    private static final Set<String> SCOPE_TYPES = Set.of(
            "self", "owned", "tenant", "organization", "area", "user-consented", "server-assigned");
    private static final Set<String> PHYSICAL_IMPACTS = Set.of(
            "none", "informational-overlay", "navigation-guidance", "spatial-placement",
            "device-interaction", "external-actuation");

    private final ObjectMapper mapper;
    private final ExtensionCapabilityCatalog capabilities;
    private final JsonSchema schema;

    public ExtensionManifestValidator(ObjectMapper mapper, ExtensionCapabilityCatalog capabilities, JsonSchema schema) {
        this.mapper = mapper;
        this.capabilities = capabilities;
        this.schema = schema;
    }

    public record ValidationResult(boolean valid, List<String> violations, List<String> highRiskCapabilities) {
        public ValidationResult {
            violations = List.copyOf(violations);
            highRiskCapabilities = List.copyOf(highRiskCapabilities);
        }
    }

    public ValidationResult validate(String json) {
        List<String> errors = new ArrayList<>();
        final JsonNode root;
        try {
            root = mapper.reader()
                    .with(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
                    .readTree(json);
        } catch (IOException | RuntimeException exception) {
            return new ValidationResult(false, List.of("manifest: invalid JSON"), List.of());
        }
        if (root == null || !root.isObject()) {
            return new ValidationResult(false, List.of("manifest: root must be an object"), List.of());
        }

        Set<ValidationMessage> schemaErrors = schema.validate(root);
        schemaErrors.stream()
                .map(ValidationMessage::getMessage)
                .sorted()
                .forEach(message -> errors.add("schema: " + message));

        String packageId = text(root, "id");
        if (packageId == null || !IDENTIFIER.matcher(packageId).matches()) errors.add("id: invalid package identifier");
        String version = text(root, "version");
        if (version == null || !SEMVER.matcher(version).matches()) errors.add("version: must be semantic version");
        String packageType = text(root, "packageType");
        if (packageType == null || !PACKAGE_TYPES.contains(packageType)) errors.add("packageType: unsupported package type");

        JsonNode publisher = root.path("publisher");
        if (publisher.isObject()) {
            String publisherId = text(publisher, "id");
            if (publisherId == null || !IDENTIFIER.matcher(publisherId).matches()) errors.add("publisher.id: invalid identifier");
        }

        Set<String> requested = new TreeSet<>();
        Set<String> highRisk = new TreeSet<>();
        JsonNode capabilityArray = root.path("capabilities");
        if (capabilityArray.isArray()) {
            for (int i = 0; i < capabilityArray.size(); i++) {
                JsonNode item = capabilityArray.get(i);
                if (!item.isObject()) continue;
                String capabilityId = text(item, "id");
                if (capabilityId == null) continue;
                requested.add(capabilityId);
                var definition = capabilities.find(capabilityId);
                if (definition.isEmpty()) {
                    errors.add("capabilities[" + i + "].id: unknown capability");
                } else if (definition.get().highRisk()) {
                    highRisk.add(capabilityId);
                }
            }
        }

        JsonNode permissions = root.path("permissions");
        if (permissions.isArray()) {
            Set<String> permissionKeys = new TreeSet<>();
            for (int i = 0; i < permissions.size(); i++) {
                JsonNode item = permissions.get(i);
                String path = "permissions[" + i + "]";
                if (!item.isObject()) continue;
                String permissionId = text(item, "id");
                String access = text(item, "access");
                if (permissionId == null || !requested.contains(permissionId)
                        || capabilities.find(permissionId).isEmpty()) {
                    errors.add(path + ".id: permission must correspond to a declared known capability");
                }
                if (permissionId != null && access != null && !permissionKeys.add(permissionId + ":" + access)) {
                    errors.add(path + ": duplicate permission");
                }
                if (access == null || !ACCESS.contains(access)) errors.add(path + ".access: unsupported access");
                String scopeType = text(item.path("scope"), "type");
                if (scopeType == null || !SCOPE_TYPES.contains(scopeType)) errors.add(path + ".scope.type: unsupported scope");
            }
        }

        JsonNode safety = root.path("safety");
        String impact = text(safety, "physicalWorldImpact");
        if (impact == null || !PHYSICAL_IMPACTS.contains(impact)) {
            errors.add("safety.physicalWorldImpact: unsupported impact classification");
        }
        return new ValidationResult(errors.isEmpty(), errors, new ArrayList<>(highRisk));
    }

    private static String text(JsonNode node, String field) {
        JsonNode value = node == null ? null : node.get(field);
        return value != null && value.isTextual() && !value.asText().isBlank() ? value.asText() : null;
    }
}
