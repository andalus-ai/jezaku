package tech.kayys.jezaku.engagement;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HttpFrameAdaptersTest {
    @Test
    void buildsAndEncodesTheMemoryOwnerUri() {
        var owners = new HttpFrameOwners(Optional.of("http://memory.local/"), 3);

        assertEquals("http://memory.local/memories/m%201/owner", owners.ownerUri("m 1").toString());
    }

    @Test
    void requiresBaseUrls() {
        assertThrows(IllegalStateException.class, () -> new HttpFrameOwners(Optional.empty(), 3).ownerUri("m1"));
        assertThrows(IllegalStateException.class,
                () -> new HttpFrameRelationships(Optional.empty(), 3).batchUri());
    }

    @Test
    void readsTheOwnerFromTheResponse() throws Exception {
        var owners = new HttpFrameOwners(Optional.of("http://memory.local"), 3);

        assertEquals("owner_1", owners.ownerFromJson("{\"memoryId\":\"m1\",\"ownerId\":\"owner_1\"}"));
        assertNull(owners.ownerFromJson("{\"memoryId\":\"m1\"}"));
    }

    @Test
    void serialisesTheBatchRequestAndReadsFriendships() throws Exception {
        var social = new HttpFrameRelationships(Optional.of("http://social.local"), 3);

        var request = new ObjectMapper().readTree(social.requestJson("viewer", List.of("a", "b")));
        assertEquals("viewer", request.get("viewerId").asText());
        assertEquals(2, request.get("ownerIds").size());
        assertEquals("http://social.local/social/relationships/context/batch", social.batchUri().toString());

        var parsed = social.fromJson("""
                {"viewerId":"viewer","count":2,"contexts":[
                  {"viewerId":"viewer","ownerId":"a","directFriend":true,"blocked":false},
                  {"viewerId":"viewer","ownerId":"b","directFriend":true,"blocked":true}]}
                """);
        assertTrue(parsed.get("a").friendly());
        assertFalse(parsed.get("b").friendly());
    }
}
