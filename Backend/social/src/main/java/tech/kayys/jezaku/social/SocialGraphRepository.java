package tech.kayys.jezaku.social;

/**
 * Compatibility facade for the social graph persistence boundary while domain stores split apart.
 */
interface SocialGraphRepository extends
        SocialGraphMetadataStore,
        SocialRelationshipGraphStore,
        SocialCircleGraphStore,
        SocialContentGraphStore,
        SocialActivityGraphStore,
        SocialMonetizationGraphStore {
}
