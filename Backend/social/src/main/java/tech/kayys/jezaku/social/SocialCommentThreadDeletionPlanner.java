package tech.kayys.jezaku.social;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Queue;

/**
 * Plans safe bottom-up deletion order for a comment thread and its replies.
 */
final class SocialCommentThreadDeletionPlanner {
    List<String> deletionOrder(List<SocialCommentRecord> comments, String rootCommentId) {
        LinkedHashSet<String> commentIds = new LinkedHashSet<>();
        Queue<String> queue = new ArrayDeque<>();
        queue.add(rootCommentId);
        while (!queue.isEmpty()) {
            String currentCommentId = queue.remove();
            if (!commentIds.add(currentCommentId)) {
                continue;
            }
            comments.stream()
                    .filter(comment -> comment.parentCommentId().equals(currentCommentId))
                    .map(SocialCommentRecord::commentId)
                    .forEach(queue::add);
        }
        List<String> traversalOrder = List.copyOf(commentIds);
        List<String> deleteOrder = new ArrayList<>();
        for (int index = traversalOrder.size() - 1; index >= 0; index--) {
            deleteOrder.add(traversalOrder.get(index));
        }
        return deleteOrder;
    }
}
