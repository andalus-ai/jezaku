package tech.kayys.jezaku.extensions.validation;

import java.util.Map;
import java.util.Optional;

/**
 * Backend-owned allowlist. Adding a capability requires a reviewed code change;
 * a manifest can request a capability but cannot define one.
 */
public final class ExtensionCapabilityCatalog {
    public record Definition(String id, String description, boolean highRisk) {}

    private static final Map<String, Definition> DEFINITIONS = Map.ofEntries(
            entry("spatial.object.read", "Read public or explicitly shared spatial objects.", false),
            entry("spatial.object.create", "Create extension-owned spatial objects.", false),
            entry("spatial.object.update.owned", "Update spatial objects owned by this installation.", false),
            entry("spatial.scene.compose", "Compose declarative scene content.", false),
            entry("spatial.render", "Contribute declarative renderable content.", false),
            entry("spatial.anchor.read", "Read anchors available to the current session.", false),
            entry("spatial.anchor.create", "Request creation of an anchor subject to spatial policy.", true),
            entry("spatial.location.coarse", "Access coarse location after applicable consent.", true),
            entry("spatial.location.precise", "Access precise location after explicit consent.", true),
            entry("spatial.navigation.target.read", "Read permitted navigation targets.", false),
            entry("spatial.navigation.route.request", "Request a route through the navigation service.", false),
            entry("commerce.storefront.read", "Read published storefront information.", false),
            entry("commerce.offer.read", "Read published offers.", false),
            entry("commerce.redemption.request", "Request redemption through the commerce service.", true),
            entry("ads.campaign.read", "Read eligible sponsored campaign metadata.", false),
            entry("ads.impression.report", "Report a disclosed ad impression through the host.", false),
            entry("safety.content.submit", "Submit content for safety review.", false),
            entry("safety.report.read.own", "Read safety reports submitted by this installation.", false),
            entry("notifications.send", "Send host-mediated, user-visible notifications subject to limits.", true)
    );

    private static Map.Entry<String, Definition> entry(String id, String description, boolean highRisk) {
        return Map.entry(id, new Definition(id, description, highRisk));
    }

    public Optional<Definition> find(String id) {
        return Optional.ofNullable(DEFINITIONS.get(id));
    }

    public Map<String, Definition> definitions() {
        return DEFINITIONS;
    }
}
