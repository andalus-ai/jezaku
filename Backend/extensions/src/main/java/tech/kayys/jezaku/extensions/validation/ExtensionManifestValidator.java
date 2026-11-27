package tech.kayys.jezaku.extensions.validation;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Validates the security-relevant subset of manifest v1.0.0 at the API boundary.
 * Validation never creates grants or marks a package approved.
 */
public class ExtensionManifestValidator {
    private static final String MANIFEST_VERSION = "1.0.0";
    private static final Pattern IDENTIFIER = Pattern.compile("^[a-z0-9][a-z0-9.-]{2,127}$");
    private static final Pattern SEMVER = Pattern.compile(
            "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\\+[0-9A-Za-z.-]+)?$");
    private static final Set<String> PACKAGE_TYPES = Set.of(
            "declarative-object", "asset-pack", "experience", "provider-adapter", "integration", "sandboxed-module");
    private static final Set<String> ACCESS = Set.of("read", "create", "update", "delete", "invoke");
    private static final Set<String> SCOPE_TYPES = Set.of(
            "self", "owned", "tenant", "organization", "area", "user-consented", "server-assigned");

    private final ObjectMapper mapper;
    private final ExtensionCapabilityCatalog capabilities;

    public ExtensionManifestValidator(ObjectMapper mapper, ExtensionCapabilityCatalog capabilities) {
        this.mapper = mapper;
        this.capabilities = capabilities;
    }

    public record ValidationResult(boolean valid, List<String> violations) {
        public ValidationResult {
            violations = List.copyOf(violations);
        }
    }

    public ValidationResult validate(String json) {
        List<String> errors = new ArrayList<>();
        final JsonNode root;
        try {
            root = mapper.readTree(json);
        } catch (IOException | RuntimeException exception) {
            return new ValidationResult(false, List.of("manifest: invalid JSON"));
        }
        if (root == null || !root.isObject()) {
            return new ValidationResult(false, List.of("manifest: root must be an object"));
        }

        requireText(root, "manifestVersion", errors);
        if (!MANIFEST_VERSION.equals(text(root, "manifestVersion"))) errors.add("manifestVersion: unsupported version");
        String packageId = text(root, "id");
        if (packageId == null || !IDENTIFIER.matcher(packageId).matches()) errors.add("id: invalid package identifier");
        String version = text(root, "version");
        if (version == null || !SEMVER.matcher(version).matches()) errors.add("version: must be semantic version");
        String packageType = text(root, "packageType");
        if (packageType == null || !PACKAGE_TYPES.contains(packageType)) errors.add("packageType: unsupported package type");

        JsonNode publisher = root.path("publisher");
        if (!publisher.isObject()) {
            errors.add("publisher: required object");
        } else {
            String publisherId = text(publisher, "id");
            if (publisherId == null || !IDENTIFIER.matcher(publisherId).matches()) errors.add("publisher.id: invalid identifier");
            requireText(publisher, "displayName", errors, "publisher.displayName");
        }

        JsonNode compatibility = root.path("compatibility");
        if (!compatibility.isObject()) errors.add("compatibility: required object");
        else requireText(compatibility, "jezakuApi", errors, "compatibility.jezakuApi");

        Set<String> requested = new HashSet<>();
        JsonNode capabilityArray = root.path("capabilities");
        if (!capabilityArray.isArray()) {
            errors.add("capabilities: required array");
        } else {
            for (int i = 0; i < capabilityArray.size(); i++) {
                JsonNode item = capabilityArray.get(i);
                String path = "capabilities[" + i + "]";
                if (!item.isObject()) { errors.add(path + ": must be an object"); continue; }
                String capabilityId = text(item, "id");
                if (capabilityId == null) errors.add(path + ".id: required");
                else {
                    if (!requested.add(capabilityId)) errors.add(path + ".id: duplicate capability");
                    if (capabilities.find(capabilityId).isEmpty()) errors.add(path + ".id: unknown capability");
                }
                requireText(item, "rationale", errors, path + ".rationale");
            }
        }

        JsonNode permissions = root.path("permissions");
        if (!permissions.isArray()) {
            errors.add("permissions: required array");
        } else {
            Set<String> permissionKeys = new HashSet<>();
            for (int i = 0; i < permissions.size(); i++) {
                JsonNode item = permissions.get(i);
                String path = "permissions[" + i + "]";
                if (!item.isObject()) { errors.add(path + ": must be an object"); continue; }
                String permissionId = text(item, "id");
                String access = text(item, "access");
                if (permissionId == null || !requested.contains(permissionId)) {
                    errors.add(path + ".id: permission must correspond to a declared known capability");
                }
                if (permissionId != null && access != null && !permissionKeys.add(permissionId + ":" + access)) {
                    errors.add(path + ": duplicate permission");
                }
                if (access == null || !ACCESS.contains(access)) errors.add(path + ".access: unsupported access");
                JsonNode scope = item.path("scope");
                String scopeType = text(scope, "type");
                if (!scope.isObject() || scopeType == null || !SCOPE_TYPES.contains(scopeType)) {
                    errors.add(path + ".scope.type: unsupported scope");
                }
                requireText(item, "purpose", errors, path + ".purpose");
            }
        }

        JsonNode privacy = root.path("privacy");
        if (!privacy.isObject()) errors.add("privacy: required object");
        else requireText(privacy, "retention", errors, "privacy.retention");
        JsonNode safety = root.path("safety");
        if (!safety.isObject()) errors.add("safety: required object");
        else {
            if (!safety.path("contentCategories").isArray()) errors.add("safety.contentCategories: required array");
            String impact = text(safety, "physicalWorldImpact");
            if (impact == null || !Set.of("none", "informational-overlay", "navigation-guidance",
                    "spatial-placement", "device-interaction", "external-actuation").contains(impact)) {
                errors.add("safety.physicalWorldImpact: unsupported impact classification");
            }
        }
        if (!root.path("assets").isArray()) errors.add("assets: required array");
        return new ValidationResult(errors.isEmpty(), errors);
    }

    private static String text(JsonNode node, String field) {
        JsonNode value = node == null ? null : node.get(field);
        return value != null && value.isTextual() && !value.asText().isBlank() ? value.asText() : null;
    }

    private static void requireText(JsonNode node, String field, List<String> errors) {
        requireText(node, field, errors, field);
    }

    private static void requireText(JsonNode node, String field, List<String> errors, String path) {
        if (text(node, field) == null) errors.add(path + ": required non-empty string");
    }
}
