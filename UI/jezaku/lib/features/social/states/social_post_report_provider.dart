import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social_post.dart';
import '../models/social_post_report.dart';
import 'social_post_providers.dart';

final socialPostReportsProvider =
    NotifierProvider<SocialPostReportController, List<SocialPostReport>>(
  SocialPostReportController.new,
);

class SocialPostReportController extends Notifier<List<SocialPostReport>> {
  @override
  List<SocialPostReport> build() {
    return const <SocialPostReport>[];
  }

  void reportPost(
    SocialPost post, {
    String reason = 'Reported from social feed',
  }) {
    state = [
      ...state,
      SocialPostReport(
        postId: post.id,
        username: post.username,
        caption: post.caption,
        reason: reason,
        reportedAt: DateTime.now(),
      ),
    ];
    ref.read(socialPostsProvider.notifier).hidePost(post.id);
  }
}
