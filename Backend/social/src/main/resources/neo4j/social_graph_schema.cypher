// Jezaku social graph baseline for Neo4j.
// This file captures the first production graph shape used by the social service.

CREATE CONSTRAINT jezaku_user_id IF NOT EXISTS
FOR (user:User)
REQUIRE user.userId IS UNIQUE;

CREATE CONSTRAINT jezaku_user_handle IF NOT EXISTS
FOR (user:User)
REQUIRE user.handle IS UNIQUE;

CREATE CONSTRAINT jezaku_group_id IF NOT EXISTS
FOR (group:Group)
REQUIRE group.groupId IS UNIQUE;

CREATE CONSTRAINT jezaku_community_id IF NOT EXISTS
FOR (community:Community)
REQUIRE community.communityId IS UNIQUE;

CREATE CONSTRAINT jezaku_content_id IF NOT EXISTS
FOR (content:Content)
REQUIRE content.contentId IS UNIQUE;

CREATE CONSTRAINT jezaku_comment_id IF NOT EXISTS
FOR (comment:Comment)
REQUIRE comment.commentId IS UNIQUE;

CREATE CONSTRAINT jezaku_activity_id IF NOT EXISTS
FOR (activity:Activity)
REQUIRE activity.activityId IS UNIQUE;

CREATE CONSTRAINT jezaku_ad_campaign_id IF NOT EXISTS
FOR (campaign:AdCampaign)
REQUIRE campaign.campaignId IS UNIQUE;

CREATE CONSTRAINT jezaku_ad_event_id IF NOT EXISTS
FOR (event:AdEvent)
REQUIRE event.eventId IS UNIQUE;

CREATE CONSTRAINT jezaku_topic_tag IF NOT EXISTS
FOR (topic:Topic)
REQUIRE topic.tag IS UNIQUE;

CREATE INDEX jezaku_user_display_name IF NOT EXISTS
FOR (user:User)
ON (user.displayName);

CREATE INDEX jezaku_friend_request_id IF NOT EXISTS
FOR ()-[request:FRIEND_REQUEST]-()
ON (request.id);

CREATE INDEX jezaku_user_follow_request IF NOT EXISTS
FOR ()-[request:FOLLOW_REQUESTED]-()
ON (request.status, request.updatedAt);

CREATE INDEX jezaku_circle_join_request_id IF NOT EXISTS
FOR ()-[request:JOIN_REQUESTED]-()
ON (request.requestId);

CREATE INDEX jezaku_circle_invite_id IF NOT EXISTS
FOR ()-[invite:INVITED_TO]-()
ON (invite.requestId);

CREATE INDEX jezaku_circle_content_moderation_id IF NOT EXISTS
FOR ()-[moderation:MODERATED_CONTENT]-()
ON (moderation.moderationId);

CREATE INDEX jezaku_mute_target IF NOT EXISTS
FOR ()-[mute:MUTED]-()
ON (mute.targetType, mute.targetId);

CREATE INDEX jezaku_share_id IF NOT EXISTS
FOR ()-[share:SHARED]-()
ON (share.shareId);

CREATE INDEX jezaku_content_report_id IF NOT EXISTS
FOR ()-[report:REPORTED]-()
ON (report.reportId);

CREATE INDEX jezaku_mention_id IF NOT EXISTS
FOR ()-[mention:MENTIONS]-()
ON (mention.mentionId);

CREATE INDEX jezaku_content_owner_scope IF NOT EXISTS
FOR (content:Content)
ON (content.ownerId, content.scope);

CREATE INDEX jezaku_comment_content IF NOT EXISTS
FOR (comment:Comment)
ON (comment.contentId);

CREATE INDEX jezaku_comment_parent IF NOT EXISTS
FOR (comment:Comment)
ON (comment.parentCommentId);

CREATE INDEX jezaku_activity_recipient IF NOT EXISTS
FOR (activity:Activity)
ON (activity.recipientId, activity.createdAt);

CREATE INDEX jezaku_activity_actor IF NOT EXISTS
FOR (activity:Activity)
ON (activity.actorId, activity.createdAt);

CREATE INDEX jezaku_ad_campaign_advertiser IF NOT EXISTS
FOR (campaign:AdCampaign)
ON (campaign.advertiserId, campaign.createdAt);

CREATE INDEX jezaku_ad_campaign_status IF NOT EXISTS
FOR (campaign:AdCampaign)
ON (campaign.status, campaign.updatedAt);

CREATE INDEX jezaku_ad_campaign_creative_review IF NOT EXISTS
FOR (campaign:AdCampaign)
ON (campaign.creativeReviewStatus, campaign.updatedAt);

CREATE INDEX jezaku_ad_event_campaign IF NOT EXISTS
FOR (event:AdEvent)
ON (event.campaignId, event.occurredAt);

CREATE INDEX jezaku_ad_event_viewer IF NOT EXISTS
FOR (event:AdEvent)
ON (event.viewerId, event.occurredAt);

// Core relationship types:
// (:User {userId, handle, displayName, bio, avatarUrl, websiteUrl, locationLabel, profileVisibility, profileCreatedAt, profileUpdatedAt})
// (:User)-[:FRIEND {createdAt, since, weight}]-(:User)
// (:User)-[:FRIEND_REQUEST {id, message, status, createdAt, updatedAt}]->(:User)
// (:User)-[:CLOSE_FRIEND {createdAt, weight}]->(:User)
// (:User)-[:FOLLOWS_USER {createdAt}]->(:User)
// (:User)-[:FOLLOW_REQUESTED {status, createdAt, updatedAt}]->(:User)
// (:User)-[:FAMILY {relationship, since, weight}]-(:User)
// (:User)-[:MEMBER_OF {role, createdAt, joinedAt, weight}]->(:Group)
// (:User)-[:MEMBER_OF {role, createdAt, joinedAt, weight}]->(:Community)
// (:User)-[:JOIN_REQUESTED {requestId, actorUserId, status, message, createdAt, updatedAt}]->(:Group|:Community)
// (:User)-[:INVITED_TO {requestId, actorUserId, status, message, createdAt, updatedAt}]->(:Group|:Community)
// (:User)-[:BLOCKED {reason, createdAt}]->(:User)
// (:User)-[:MUTED {targetType, targetId, reason, createdAt}]->(:User|:Group|:Community)
// (:User)-[:CREATED {createdAt}]->(:Content {contentId, ownerId, contentType, scope, targetId, caption, createdAt})
// (:User)-[:MODERATED_CONTENT {moderationId, targetId, targetType, action, status, reason, createdAt, updatedAt}]->(:Content)
// (:Content)-[:TAGGED_WITH {createdAt}]->(:Topic {tag})
// (:User)-[:FOLLOWS_TOPIC {createdAt}]->(:Topic)
// (:User)-[:REACTED_TO {reactionType, createdAt}]->(:Content)
// (:User)-[:WROTE {createdAt}]->(:Comment {commentId, contentId, authorId, text, parentCommentId, createdAt})-[:ON_CONTENT]->(:Content)
// (:Comment)-[:REPLIED_TO {createdAt}]->(:Comment)
// (:User)-[:REACTED_TO_COMMENT {reactionType, createdAt}]->(:Comment)
// (:User)-[:SAVED {createdAt}]->(:Content)
// (:User)-[:SHARED {shareId, message, createdAt}]->(:Content)
// (:User)-[:HIDDEN_CONTENT {reason, createdAt}]->(:Content)
// (:User)-[:REPORTED {reportId, reason, detail, status, createdAt, updatedAt}]->(:Content)
// (:Content)-[:MENTIONS {mentionId, commentId, actorId, sourceType, createdAt}]->(:User)
// (:User)-[:PERFORMED {createdAt}]->(:Activity {activityId, eventType, actorId, recipientId, contentId, commentId, reactionType, message, createdAt, read})-[:DELIVERED_TO]->(:User)
// (:User)-[:ADVERTISER_OF {createdAt}]->(:AdCampaign {campaignId, advertiserId, name, objective, status, creativeContentId, creativeReviewStatus, creativeReviewReason, creativeReviewedAt, budgetCurrency, budgetCents, startsAt, endsAt, maxDepth, audienceLimit, estimatedReach, relationScopes, targetTags, targetGroupIds, targetCommunityIds, createdAt, updatedAt})
// (:AdCampaign)-[:EMITTED_AD_EVENT {createdAt}]->(:AdEvent {eventId, campaignId, advertiserId, viewerId, eventType, placement, creativeContentId, occurredAt, createdAt})<-[:AD_EVENT_VIEWER]-(:User)

// Friends-of-friends projection:
// MATCH (user:User {userId: $userId})-[:FRIEND]-(friend:User)-[:FRIEND]-(candidate:User)
// WHERE candidate <> user AND NOT (user)-[:FRIEND]-(candidate)
// RETURN candidate, count(friend) AS mutualFriendCount
// ORDER BY mutualFriendCount DESC
// LIMIT $limit;

// User social network projection:
// MATCH path = (user:User {userId: $userId})-[:FRIEND|FAMILY|MEMBER_OF*1..$maxDepth]-(node)
// WHERE NONE(rel IN relationships(path) WHERE type(rel) = 'BLOCKED')
// RETURN nodes(path) AS nodes, relationships(path) AS relationships;
