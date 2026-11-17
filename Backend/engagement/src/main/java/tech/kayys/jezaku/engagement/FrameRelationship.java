package tech.kayys.jezaku.engagement;

/** How one user relates to another, as far as frame comments care: blocked, or a direct friend. */
record FrameRelationship(boolean blocked, boolean directFriend) {
    static final FrameRelationship NONE = new FrameRelationship(false, false);

    boolean friendly() {
        return directFriend && !blocked;
    }
}
