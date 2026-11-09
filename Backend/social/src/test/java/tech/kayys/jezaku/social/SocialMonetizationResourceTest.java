package tech.kayys.jezaku.social;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.parallel.Execution;
import org.junit.jupiter.api.parallel.ExecutionMode;

import java.time.Instant;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.greaterThan;
import static org.hamcrest.Matchers.greaterThanOrEqualTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;

/**
 * Exercises monetization HTTP endpoints for ad audience, campaigns, delivery, events, and reporting.
 */
@QuarkusTest
@Execution(ExecutionMode.SAME_THREAD)
class SocialMonetizationResourceTest extends SocialResourceHttpTestSupport {
    @Inject
    SocialGraphRepository repository;

    @Inject
    SocialService service;

    @Override
    protected SocialGraphRepository repository() {
        return repository;
    }

    @Override
    protected SocialService service() {
        return service;
    }

    @Test
    void previewsMonetizationAdAudienceFromGraphAndInterests() {
        String targetTag = "adsignal" + UUID.randomUUID().toString().replace("-", "").substring(0, 8);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens"
                        }
                        """)
                .when()
                .put("/social/tags/{tag}/follows", targetTag)
                .then()
                .statusCode(200)
                .body("tag", equalTo(targetTag));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "advertiserId": "user_current",
                          "objective": "awareness",
                          "relationScopes": ["friend_of_friend", "shared_group", "shared_community"],
                          "targetTags": ["#%s"],
                          "targetGroupIds": ["group_rooftop_creators"],
                          "targetCommunityIds": ["community_bandung_campus"],
                          "maxDepth": 2,
                          "limit": 10
                        }
                        """.formatted(targetTag))
                .when()
                .post("/social/monetization/ad-audience/preview")
                .then()
                .statusCode(200)
                .body("advertiserId", equalTo("user_current"))
                .body("objective", equalTo("awareness"))
                .body("maxDepth", equalTo(2))
                .body("limit", equalTo(10))
                .body("estimatedReach", greaterThanOrEqualTo(1))
                .body("returnedCount", greaterThanOrEqualTo(1))
                .body("blockedExcludedCount", greaterThanOrEqualTo(1))
                .body("targetTagCount", equalTo(1))
                .body("targetGroupCount", equalTo(1))
                .body("targetCommunityCount", equalTo(1))
                .body("candidates.userId", hasItem("user_lens"))
                .body("candidates.find { it.userId == 'user_lens' }.primaryRelation",
                        equalTo("friend_of_friend"))
                .body("candidates.find { it.userId == 'user_lens' }.connectionDepth", equalTo(2))
                .body("candidates.find { it.userId == 'user_lens' }.relations", hasItem("shared_group"))
                .body("candidates.find { it.userId == 'user_lens' }.relations", hasItem("shared_community"))
                .body("candidates.find { it.userId == 'user_lens' }.matchedTags", hasItem(targetTag))
                .body("candidates.find { it.userId == 'user_lens' }.matchedGroupIds",
                        hasItem("group_rooftop_creators"))
                .body("candidates.find { it.userId == 'user_lens' }.matchedCommunityIds",
                        hasItem("community_bandung_campus"))
                .body("candidates.find { it.userId == 'user_lens' }.relevanceScore", greaterThan(0.0f))
                .body("candidates.find { it.userId == 'user_lens' }.reasons", hasItem("target_tags"))
                .body("segments.find { it.segment == 'friend_of_friend' }.userIds", hasItem("user_lens"));

        given()
                .when()
                .delete("/social/tags/{tag}/follows/{userId}", targetTag, "user_lens")
                .then()
                .statusCode(204);
    }

    @Test
    void createsListsReadsAndSchedulesMonetizationAdCampaignDrafts() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String targetTag = "campaignsignal" + suffix;
        String creativeContentId = "campaign_creative_" + suffix;
        String campaignId = "campaign_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Campaign creative #%s"
                        }
                        """.formatted(creativeContentId, targetTag))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens"
                        }
                        """)
                .when()
                .put("/social/tags/{tag}/follows", targetTag)
                .then()
                .statusCode(200);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "campaignId": "%s",
                          "advertiserId": "user_current",
                          "name": "Rooftop Launch",
                          "objective": "engagement",
                          "creativeContentId": "%s",
                          "budgetCurrency": "usd",
                          "budgetCents": 250000,
                          "relationScopes": ["friend_of_friend", "shared_group"],
                          "targetTags": ["%s"],
                          "targetGroupIds": ["group_rooftop_creators"],
                          "targetCommunityIds": ["community_bandung_campus"],
                          "maxDepth": 2,
                          "audienceLimit": 25
                        }
                        """.formatted(campaignId, creativeContentId, targetTag))
                .when()
                .post("/social/monetization/ad-campaigns")
                .then()
                .statusCode(201)
                .body("campaignId", equalTo(campaignId))
                .body("advertiserId", equalTo("user_current"))
                .body("name", equalTo("Rooftop Launch"))
                .body("objective", equalTo("engagement"))
                .body("status", equalTo("draft"))
                .body("creativeContentId", equalTo(creativeContentId))
                .body("creativeReviewStatus", equalTo("pending_review"))
                .body("creativeReviewReason", equalTo(""))
                .body("budgetCurrency", equalTo("USD"))
                .body("budgetCents", equalTo(250000))
                .body("maxDepth", equalTo(2))
                .body("audienceLimit", equalTo(25))
                .body("estimatedReach", greaterThanOrEqualTo(1))
                .body("relationScopes", hasItem("friend_of_friend"))
                .body("targetTags", hasItem(targetTag))
                .body("targetGroupIds", hasItem("group_rooftop_creators"))
                .body("targetCommunityIds", hasItem("community_bandung_campus"));

        given()
                .when()
                .get("/social/monetization/ad-campaigns?advertiserId=user_current&status=draft&limit=10")
                .then()
                .statusCode(200)
                .body("advertiserId", equalTo("user_current"))
                .body("status", equalTo("draft"))
                .body("campaigns.campaignId", hasItem(campaignId));

        given()
                .when()
                .get("/social/monetization/ad-campaigns/{campaignId}?advertiserId=user_current", campaignId)
                .then()
                .statusCode(200)
                .body("campaignId", equalTo(campaignId))
                .body("status", equalTo("draft"));

        given()
                .when()
                .get("/social/monetization/ad-campaigns/{campaignId}?advertiserId=user_lens", campaignId)
                .then()
                .statusCode(403);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "advertiserId": "user_current",
                          "status": "scheduled"
                        }
                        """)
                .when()
                .put("/social/monetization/ad-campaigns/{campaignId}/status", campaignId)
                .then()
                .statusCode(200)
                .body("campaignId", equalTo(campaignId))
                .body("status", equalTo("scheduled"))
                .body("creativeReviewStatus", equalTo("pending_review"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "advertiserId": "user_current",
                          "status": "approved",
                          "reason": "Creative matches community guidelines"
                        }
                        """)
                .when()
                .put("/social/monetization/ad-campaigns/{campaignId}/creative-review", campaignId)
                .then()
                .statusCode(200)
                .body("campaignId", equalTo(campaignId))
                .body("creativeReviewStatus", equalTo("approved"))
                .body("creativeReviewReason", equalTo("Creative matches community guidelines"));

        given()
                .when()
                .delete("/social/tags/{tag}/follows/{userId}", targetTag, "user_lens")
                .then()
                .statusCode(204);
    }

    @Test
    void returnsEligibleMonetizationAdDeliveryCandidates() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String targetTag = "deliverysignal" + suffix;
        String creativeContentId = "delivery_creative_" + suffix;
        String campaignId = "delivery_campaign_" + suffix;
        Instant campaignStartsAt = Instant.now().minusSeconds(86_400L);
        Instant campaignEndsAt = campaignStartsAt.plusSeconds(7 * 86_400L);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Delivery creative #%s"
                        }
                        """.formatted(creativeContentId, targetTag))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens"
                        }
                        """)
                .when()
                .put("/social/tags/{tag}/follows", targetTag)
                .then()
                .statusCode(200);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "campaignId": "%s",
                          "advertiserId": "user_current",
                          "name": "Delivery Launch",
                          "objective": "traffic",
                          "creativeContentId": "%s",
                          "budgetCurrency": "USD",
                          "budgetCents": 180000,
                          "startsAt": "%s",
                          "endsAt": "%s",
                          "relationScopes": ["friend_of_friend", "shared_group"],
                          "targetTags": ["%s"],
                          "targetGroupIds": ["group_rooftop_creators"],
                          "maxDepth": 2,
                          "audienceLimit": 25
                        }
                        """.formatted(campaignId, creativeContentId, campaignStartsAt, campaignEndsAt, targetTag))
                .when()
                .post("/social/monetization/ad-campaigns")
                .then()
                .statusCode(201)
                .body("status", equalTo("draft"))
                .body("creativeReviewStatus", equalTo("pending_review"));

        given()
                .when()
                .get("/social/monetization/ad-delivery?viewerId=user_lens&placement=feed&limit=20")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_lens"))
                .body("placement", equalTo("feed"))
                .body("candidates.campaignId", not(hasItem(campaignId)));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "advertiserId": "user_current",
                          "status": "scheduled"
                        }
                        """)
                .when()
                .put("/social/monetization/ad-campaigns/{campaignId}/status", campaignId)
                .then()
                .statusCode(200)
                .body("status", equalTo("scheduled"))
                .body("creativeReviewStatus", equalTo("pending_review"));

        given()
                .when()
                .get("/social/monetization/ad-delivery?viewerId=user_lens&placement=feed&limit=20")
                .then()
                .statusCode(200)
                .body("candidates.campaignId", not(hasItem(campaignId)));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "advertiserId": "user_current",
                          "status": "approved",
                          "reason": "Approved for delivery test"
                        }
                        """)
                .when()
                .put("/social/monetization/ad-campaigns/{campaignId}/creative-review", campaignId)
                .then()
                .statusCode(200)
                .body("creativeReviewStatus", equalTo("approved"));

        given()
                .when()
                .get("/social/monetization/ad-delivery?viewerId=user_lens&placement=feed&limit=20")
                .then()
                .statusCode(200)
                .body("viewerId", equalTo("user_lens"))
                .body("placement", equalTo("feed"))
                .body("limit", equalTo(20))
                .body("candidates.campaignId", hasItem(campaignId))
                .body("candidates.find { it.campaignId == '%s' }.advertiserId".formatted(campaignId),
                        equalTo("user_current"))
                .body("candidates.find { it.campaignId == '%s' }.creativeContentId".formatted(campaignId),
                        equalTo(creativeContentId))
                .body("candidates.find { it.campaignId == '%s' }.primaryRelation".formatted(campaignId),
                        equalTo("friend_of_friend"))
                .body("candidates.find { it.campaignId == '%s' }.matchedTags".formatted(campaignId),
                        hasItem(targetTag))
                .body("candidates.find { it.campaignId == '%s' }.matchedGroupIds".formatted(campaignId),
                        hasItem("group_rooftop_creators"))
                .body("candidates.find { it.campaignId == '%s' }.deliveryScore".formatted(campaignId),
                        greaterThan(0.0f))
                .body("candidates.find { it.campaignId == '%s' }.reasons".formatted(campaignId),
                        hasItem("campaign_scheduled"))
                .body("candidates.find { it.campaignId == '%s' }.reasons".formatted(campaignId),
                        hasItem("creative_review:approved"))
                .body("candidates.find { it.campaignId == '%s' }.reasons".formatted(campaignId),
                        hasItem("creative_visible"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "eventId": "impression_%s_1",
                          "campaignId": "%s",
                          "viewerId": "user_lens",
                          "eventType": "impression",
                          "placement": "feed"
                        }
                        """.formatted(suffix, campaignId))
                .when()
                .post("/social/monetization/ad-events")
                .then()
                .statusCode(201)
                .body("eventId", equalTo("impression_%s_1".formatted(suffix)))
                .body("campaignId", equalTo(campaignId))
                .body("advertiserId", equalTo("user_current"))
                .body("viewerId", equalTo("user_lens"))
                .body("eventType", equalTo("impression"))
                .body("placement", equalTo("feed"))
                .body("creativeContentId", equalTo(creativeContentId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "eventId": "click_%s_1",
                          "campaignId": "%s",
                          "viewerId": "user_lens",
                          "eventType": "click",
                          "placement": "feed"
                        }
                        """.formatted(suffix, campaignId))
                .when()
                .post("/social/monetization/ad-events")
                .then()
                .statusCode(201)
                .body("eventType", equalTo("click"));

        given()
                .when()
                .get("/social/monetization/ad-campaigns/{campaignId}/metrics?advertiserId=user_current", campaignId)
                .then()
                .statusCode(200)
                .body("campaignId", equalTo(campaignId))
                .body("advertiserId", equalTo("user_current"))
                .body("status", equalTo("scheduled"))
                .body("budgetCurrency", equalTo("USD"))
                .body("budgetCents", equalTo(180000))
                .body("spentCents", equalTo(26))
                .body("remainingBudgetCents", equalTo(179974))
                .body("budgetExhausted", equalTo(false))
                .body("impressionCount", equalTo(1))
                .body("clickCount", equalTo(1))
                .body("conversionCount", equalTo(0))
                .body("uniqueViewerCount", equalTo(1))
                .body("clickThroughRate", equalTo(1.0f))
                .body("placementMetrics.placement", hasItem("feed"))
                .body("placementMetrics.find { it.placement == 'feed' }.spentCents", equalTo(26))
                .body("placementMetrics.find { it.placement == 'feed' }.impressionCount", equalTo(1))
                .body("placementMetrics.find { it.placement == 'feed' }.clickCount", equalTo(1))
                .body("placementMetrics.find { it.placement == 'feed' }.conversionCount", equalTo(0))
                .body("placementMetrics.find { it.placement == 'feed' }.uniqueViewerCount", equalTo(1))
                .body("placementMetrics.find { it.placement == 'feed' }.clickThroughRate", equalTo(1.0f))
                .body("audienceRelationMetrics.relation", hasItem("friend_of_friend"))
                .body("audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.spentCents", equalTo(26))
                .body("audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.impressionCount", equalTo(1))
                .body("audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.clickCount", equalTo(1))
                .body("audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.conversionCount", equalTo(0))
                .body("audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.uniqueViewerCount", equalTo(1))
                .body("audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.clickThroughRate", equalTo(1.0f))
                .body("audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.averageRelevanceScore",
                        greaterThan(0.0f))
                .body("budgetPacing.status", equalTo("under_pacing"))
                .body("budgetPacing.dailyBudgetCents", equalTo(25715))
                .body("budgetPacing.expectedSpentCents", greaterThan(20000))
                .body("budgetPacing.projectedSpendCents", greaterThan(0))
                .body("budgetPacing.remainingBudgetCents", equalTo(179974))
                .body("budgetPacing.secondsRemaining", greaterThan(500000));

        given()
                .when()
                .get("/social/monetization/ad-campaigns/{campaignId}/daily-report?advertiserId=user_current&days=1",
                        campaignId)
                .then()
                .statusCode(200)
                .body("campaignId", equalTo(campaignId))
                .body("advertiserId", equalTo("user_current"))
                .body("budgetCurrency", equalTo("USD"))
                .body("windowDays", equalTo(1))
                .body("buckets", hasSize(1))
                .body("buckets[0].spentCents", equalTo(26))
                .body("buckets[0].impressionCount", equalTo(1))
                .body("buckets[0].clickCount", equalTo(1))
                .body("buckets[0].conversionCount", equalTo(0))
                .body("buckets[0].uniqueViewerCount", equalTo(1))
                .body("buckets[0].clickThroughRate", equalTo(1.0f));

        given()
                .when()
                .get("/social/monetization/ad-campaigns/{campaignId}/daily-report?advertiserId=user_lens&days=1",
                        campaignId)
                .then()
                .statusCode(403);

        given()
                .when()
                .get("/social/monetization/advertisers/user_current/daily-report?status=scheduled&days=1&limit=100")
                .then()
                .statusCode(200)
                .body("advertiserId", equalTo("user_current"))
                .body("status", equalTo("scheduled"))
                .body("budgetCurrency", equalTo("USD"))
                .body("campaignCount", greaterThanOrEqualTo(1))
                .body("limit", equalTo(100))
                .body("windowDays", equalTo(1))
                .body("buckets", hasSize(1))
                .body("buckets[0].spentCents", greaterThanOrEqualTo(26))
                .body("buckets[0].impressionCount", greaterThanOrEqualTo(1))
                .body("buckets[0].clickCount", greaterThanOrEqualTo(1))
                .body("buckets[0].uniqueViewerCount", greaterThanOrEqualTo(1));

        given()
                .when()
                .get("/social/monetization/ad-campaigns/{campaignId}/billing-ledger?advertiserId=user_current&limit=10",
                        campaignId)
                .then()
                .statusCode(200)
                .body("campaignId", equalTo(campaignId))
                .body("advertiserId", equalTo("user_current"))
                .body("budgetCurrency", equalTo("USD"))
                .body("budgetCents", equalTo(180000))
                .body("spentCents", equalTo(26))
                .body("remainingBudgetCents", equalTo(179974))
                .body("budgetExhausted", equalTo(false))
                .body("count", equalTo(2))
                .body("limit", equalTo(10))
                .body("entries[0].eventId", equalTo("impression_%s_1".formatted(suffix)))
                .body("entries[0].eventType", equalTo("impression"))
                .body("entries[0].billableCents", equalTo(1))
                .body("entries[0].cumulativeSpentCents", equalTo(1))
                .body("entries[0].remainingBudgetCents", equalTo(179999))
                .body("entries[1].eventId", equalTo("click_%s_1".formatted(suffix)))
                .body("entries[1].eventType", equalTo("click"))
                .body("entries[1].billableCents", equalTo(25))
                .body("entries[1].cumulativeSpentCents", equalTo(26))
                .body("entries[1].remainingBudgetCents", equalTo(179974));

        given()
                .when()
                .get("/social/monetization/advertisers/user_current/dashboard?status=scheduled&limit=100")
                .then()
                .statusCode(200)
                .body("advertiserId", equalTo("user_current"))
                .body("status", equalTo("scheduled"))
                .body("budgetCurrency", equalTo("USD"))
                .body("count", greaterThanOrEqualTo(1))
                .body("limit", equalTo(100))
                .body("totalBudgetCents", greaterThanOrEqualTo(180000))
                .body("totalSpentCents", greaterThanOrEqualTo(26))
                .body("totalRemainingBudgetCents", greaterThanOrEqualTo(179974))
                .body("activeCampaignCount", greaterThanOrEqualTo(1))
                .body("totalImpressionCount", greaterThanOrEqualTo(1))
                .body("totalClickCount", greaterThanOrEqualTo(1))
                .body("uniqueViewerCount", greaterThanOrEqualTo(1))
                .body("placementMetrics.placement", hasItem("feed"))
                .body("placementMetrics.find { it.placement == 'feed' }.spentCents", greaterThanOrEqualTo(26))
                .body("placementMetrics.find { it.placement == 'feed' }.impressionCount", greaterThanOrEqualTo(1))
                .body("placementMetrics.find { it.placement == 'feed' }.clickCount", greaterThanOrEqualTo(1))
                .body("audienceRelationMetrics.relation", hasItem("friend_of_friend"))
                .body("audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.spentCents",
                        greaterThanOrEqualTo(26))
                .body("audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.impressionCount",
                        greaterThanOrEqualTo(1))
                .body("audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.clickCount",
                        greaterThanOrEqualTo(1))
                .body("campaigns.campaignId", hasItem(campaignId))
                .body("campaigns.find { it.campaignId == '%s' }.name".formatted(campaignId),
                        equalTo("Delivery Launch"))
                .body("campaigns.find { it.campaignId == '%s' }.spentCents".formatted(campaignId),
                        equalTo(26))
                .body("campaigns.find { it.campaignId == '%s' }.remainingBudgetCents".formatted(campaignId),
                        equalTo(179974))
                .body("campaigns.find { it.campaignId == '%s' }.budgetExhausted".formatted(campaignId),
                        equalTo(false))
                .body("campaigns.find { it.campaignId == '%s' }.impressionCount".formatted(campaignId),
                        equalTo(1))
                .body("campaigns.find { it.campaignId == '%s' }.clickCount".formatted(campaignId),
                        equalTo(1))
                .body("campaigns.find { it.campaignId == '%s' }.conversionCount".formatted(campaignId),
                        equalTo(0))
                .body("campaigns.find { it.campaignId == '%s' }.uniqueViewerCount".formatted(campaignId),
                        equalTo(1))
                .body("campaigns.find { it.campaignId == '%s' }.clickThroughRate".formatted(campaignId),
                        equalTo(1.0f))
                .body("campaigns.find { it.campaignId == '%s' }.placementMetrics.placement".formatted(campaignId),
                        hasItem("feed"))
                .body("campaigns.find { it.campaignId == '%s' }.placementMetrics.find { it.placement == 'feed' }.spentCents"
                        .formatted(campaignId), equalTo(26))
                .body("campaigns.find { it.campaignId == '%s' }.placementMetrics.find { it.placement == 'feed' }.impressionCount"
                        .formatted(campaignId), equalTo(1))
                .body("campaigns.find { it.campaignId == '%s' }.placementMetrics.find { it.placement == 'feed' }.clickCount"
                        .formatted(campaignId), equalTo(1))
                .body("campaigns.find { it.campaignId == '%s' }.audienceRelationMetrics.relation".formatted(campaignId),
                        hasItem("friend_of_friend"))
                .body("campaigns.find { it.campaignId == '%s' }.audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.spentCents"
                        .formatted(campaignId), equalTo(26))
                .body("campaigns.find { it.campaignId == '%s' }.audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.impressionCount"
                        .formatted(campaignId), equalTo(1))
                .body("campaigns.find { it.campaignId == '%s' }.audienceRelationMetrics.find { it.relation == 'friend_of_friend' }.clickCount"
                        .formatted(campaignId), equalTo(1))
                .body("campaigns.find { it.campaignId == '%s' }.budgetPacing.status".formatted(campaignId),
                        equalTo("under_pacing"))
                .body("campaigns.find { it.campaignId == '%s' }.budgetPacing.dailyBudgetCents".formatted(campaignId),
                        equalTo(25715))
                .body("campaigns.find { it.campaignId == '%s' }.budgetPacing.remainingBudgetCents".formatted(campaignId),
                        equalTo(179974));

        given()
                .when()
                .get("/social/monetization/ad-campaigns/{campaignId}/billing-ledger?advertiserId=user_lens",
                        campaignId)
                .then()
                .statusCode(403);

        for (int index = 2; index <= 3; index++) {
            given()
                    .contentType(ContentType.JSON)
                    .body("""
                            {
                              "eventId": "impression_%s_%s",
                              "campaignId": "%s",
                              "viewerId": "user_lens",
                              "eventType": "impression",
                              "placement": "feed"
                            }
                            """.formatted(suffix, index, campaignId))
                    .when()
                    .post("/social/monetization/ad-events")
                    .then()
                    .statusCode(201)
                    .body("eventType", equalTo("impression"));
        }

        given()
                .when()
                .get("/social/monetization/ad-delivery?viewerId=user_lens&placement=feed&limit=20")
                .then()
                .statusCode(200)
                .body("candidates.campaignId", not(hasItem(campaignId)));

        given()
                .when()
                .get("/social/monetization/ad-delivery?viewerId=user_blocked&placement=feed&limit=20")
                .then()
                .statusCode(200)
                .body("candidates.campaignId", not(hasItem(campaignId)));

        given()
                .when()
                .delete("/social/tags/{tag}/follows/{userId}", targetTag, "user_lens")
                .then()
                .statusCode(204);
    }

    @Test
    void stopsMonetizationAdDeliveryWhenBudgetIsExhausted() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String targetTag = "budgetsignal" + suffix;
        String creativeContentId = "budget_creative_" + suffix;
        String campaignId = "budget_campaign_" + suffix;

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "contentId": "%s",
                          "ownerId": "user_current",
                          "contentType": "photo",
                          "scope": "group",
                          "targetId": "group_rooftop_creators",
                          "caption": "Budget creative #%s"
                        }
                        """.formatted(creativeContentId, targetTag))
                .when()
                .post("/social/content")
                .then()
                .statusCode(201);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "userId": "user_lens"
                        }
                        """)
                .when()
                .put("/social/tags/{tag}/follows", targetTag)
                .then()
                .statusCode(200);

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "campaignId": "%s",
                          "advertiserId": "user_current",
                          "name": "Budget Cap Launch",
                          "objective": "conversion",
                          "creativeContentId": "%s",
                          "budgetCurrency": "USD",
                          "budgetCents": 100,
                          "relationScopes": ["friend_of_friend", "shared_group"],
                          "targetTags": ["%s"],
                          "targetGroupIds": ["group_rooftop_creators"],
                          "maxDepth": 2,
                          "audienceLimit": 25
                        }
                        """.formatted(campaignId, creativeContentId, targetTag))
                .when()
                .post("/social/monetization/ad-campaigns")
                .then()
                .statusCode(201)
                .body("status", equalTo("draft"))
                .body("creativeReviewStatus", equalTo("pending_review"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "advertiserId": "user_current",
                          "status": "scheduled"
                        }
                        """)
                .when()
                .put("/social/monetization/ad-campaigns/{campaignId}/status", campaignId)
                .then()
                .statusCode(200)
                .body("status", equalTo("scheduled"));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "advertiserId": "user_current",
                          "status": "approved",
                          "reason": "Approved for budget cap test"
                        }
                        """)
                .when()
                .put("/social/monetization/ad-campaigns/{campaignId}/creative-review", campaignId)
                .then()
                .statusCode(200)
                .body("creativeReviewStatus", equalTo("approved"));

        given()
                .when()
                .get("/social/monetization/ad-delivery?viewerId=user_lens&placement=feed&limit=20")
                .then()
                .statusCode(200)
                .body("candidates.campaignId", hasItem(campaignId));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "eventId": "conversion_%s_1",
                          "campaignId": "%s",
                          "viewerId": "user_lens",
                          "eventType": "conversion",
                          "placement": "feed"
                        }
                        """.formatted(suffix, campaignId))
                .when()
                .post("/social/monetization/ad-events")
                .then()
                .statusCode(201)
                .body("eventType", equalTo("conversion"));

        given()
                .when()
                .get("/social/monetization/ad-campaigns/{campaignId}/metrics?advertiserId=user_current", campaignId)
                .then()
                .statusCode(200)
                .body("campaignId", equalTo(campaignId))
                .body("budgetCurrency", equalTo("USD"))
                .body("budgetCents", equalTo(100))
                .body("spentCents", equalTo(100))
                .body("remainingBudgetCents", equalTo(0))
                .body("budgetExhausted", equalTo(true))
                .body("impressionCount", equalTo(0))
                .body("clickCount", equalTo(0))
                .body("conversionCount", equalTo(1))
                .body("clickThroughRate", equalTo(0.0f));

        given()
                .contentType(ContentType.JSON)
                .body("""
                        {
                          "eventId": "overspend_%s_1",
                          "campaignId": "%s",
                          "viewerId": "user_lens",
                          "eventType": "impression",
                          "placement": "feed"
                        }
                        """.formatted(suffix, campaignId))
                .when()
                .post("/social/monetization/ad-events")
                .then()
                .statusCode(409);

        given()
                .when()
                .get("/social/monetization/ad-delivery?viewerId=user_lens&placement=feed&limit=20")
                .then()
                .statusCode(200)
                .body("candidates.campaignId", not(hasItem(campaignId)));

        given()
                .when()
                .delete("/social/tags/{tag}/follows/{userId}", targetTag, "user_lens")
                .then()
                .statusCode(204);
    }
}
