/// Which frame rules a build runs.
///
/// - [demo]: offline demos and prototyping. Everyone counts as a friend and
///   the physical radius is not enforced, so every sample frame can be shown.
/// - [strict]: production. The real rules: audience (public, friends, own),
///   moderation and the physical radius. The backend enforces the same rules;
///   this is the client's defence in depth.
///
/// Pick it per build with `--dart-define=JEZAKU_FRAME_RULES=strict`. Builds
/// that do not pass it run [demo] for now. Anything other than `demo` or an
/// empty value is read as [strict], so a typo never loosens the rules.
enum FrameRulesMode {
  demo,
  strict;

  static const defineName = 'JEZAKU_FRAME_RULES';

  static FrameRulesMode parse(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return normalized.isEmpty || normalized == 'demo' ? demo : strict;
  }

  /// The mode this build was compiled with.
  static final FrameRulesMode current =
      parse(const String.fromEnvironment(defineName));
}
