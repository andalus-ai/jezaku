/// The counts shown at the top of the profile, taken from local data.
class ProfileStats {
  const ProfileStats({
    required this.memories,
    required this.walls,
    required this.pendingSync,
  });

  final int memories;
  final int walls;

  /// Memories that still have to reach the server.
  final int pendingSync;
}
