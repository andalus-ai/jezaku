/// Who a frame is shared with. The names match the memory service's
/// `visibility` values (`private | friends | public`) so they travel as is.
enum FrameAudience {
  private('Only me'),
  friends('Friends'),
  public('Public');

  const FrameAudience(this.label);

  final String label;

  /// The backend's `visibility` value.
  String get wireName => name;

  static FrameAudience fromName(Object? value, FrameAudience fallback) {
    for (final audience in values) {
      if (audience.name == value) {
        return audience;
      }
    }
    return fallback;
  }
}
