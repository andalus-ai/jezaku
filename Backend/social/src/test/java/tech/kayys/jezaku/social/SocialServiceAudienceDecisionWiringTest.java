package tech.kayys.jezaku.social;

import org.junit.jupiter.api.Test;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialCommentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialContentCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialContentResponse;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupCreateRequest;
import tech.kayys.jezaku.social.SocialDtos.SocialGroupResponse;

import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SocialServiceAudienceDecisionWiringTest {
    @Test
    void createsGroupsKeepsOwnerCircleTargetMetadataAndAllowsMemberComments() {
        InMemorySocialGraphRepository repository = new InMemorySocialGraphRepository();
        SocialService service = new SocialService(repository, null);
        repository.saveUserProfile(profile("owner", "owner", "Owner"));
        repository.saveUserProfile(profile("viewer", "viewer", "Viewer"));

        SocialGroupResponse group = service.createGroup(new SocialGroupCreateRequest(
                        "group_a",
                        "Group A",
                        "public",
                        "owner"))
                .await()
                .indefinitely();
        SocialContentResponse content = service.createContent(new SocialContentCreateRequest(
                        "content_a",
                        "owner",
                        "photo",
                        "group",
                        "group_a",
                        "Group photo #groupa"))
                .await()
                .indefinitely();
        repository.saveGroupMembership(new MembershipRecord("viewer", "group_a", "member", Instant.now()));
        SocialCommentResponse comment = service.addComment(
                        "content_a",
                        new SocialCommentCreateRequest("viewer", "I can see this group photo.", ""))
                .await()
                .indefinitely();

        assertEquals("group_a", group.groupId());
        assertEquals("group_a", content.audience().targetId());
        assertEquals("owner", content.audience().reason());
        assertEquals("content_a", comment.contentId());
        assertEquals("viewer", comment.authorId());
        assertEquals("Viewer", comment.author().displayName());
    }

    private SocialUserProfileRecord profile(String userId, String handle, String displayName) {
        Instant now = Instant.parse("2026-06-04T05:00:00Z");
        return new SocialUserProfileRecord(
                userId,
                handle,
                displayName,
                "",
                "",
                "",
                "",
                "public",
                now,
                now);
    }
}
