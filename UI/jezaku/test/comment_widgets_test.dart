import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/social/models/social_post.dart';
import 'package:jejaku/features/social/widgets/comment_composer.dart';
import 'package:jejaku/features/social/widgets/comment_tile.dart';
import 'package:material_ui/material_ui.dart';

SocialComment _comment({
  required DateTime timestamp,
  bool isMine = false,
  String username = 'maya',
}) {
  return SocialComment(
    id: 'c1',
    postId: 'p1',
    username: username,
    text: 'Nice',
    timestamp: timestamp,
    isMine: isMine,
  );
}

void main() {
  group('formatCommentAge', () {
    final now = DateTime(2026, 11, 22, 12);

    test('uses minutes under an hour, never below one', () {
      expect(
        formatCommentAge(_comment(timestamp: now), now: now),
        '1m ago',
      );
      expect(
        formatCommentAge(
          _comment(timestamp: now.subtract(const Duration(minutes: 42))),
          now: now,
        ),
        '42m ago',
      );
    });

    test('uses hours then days', () {
      expect(
        formatCommentAge(
          _comment(timestamp: now.subtract(const Duration(hours: 5))),
          now: now,
        ),
        '5h ago',
      );
      expect(
        formatCommentAge(
          _comment(timestamp: now.subtract(const Duration(days: 3))),
          now: now,
        ),
        '3d ago',
      );
    });
  });

  testWidgets('CommentTile shows the author initial, text and Just now',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentTile(
            comment: _comment(
              timestamp: DateTime(2026),
              isMine: true,
              username: 'you',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Y'), findsOneWidget);
    expect(find.textContaining('Nice', findRichText: true), findsOneWidget);
    expect(find.text('Just now'), findsOneWidget);
  });

  group('CommentComposer', () {
    testWidgets('send is disabled until there is text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentComposer(onSubmit: (_) {})),
        ),
      );

      IconButton send() => tester.widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.send),
              matching: find.byType(IconButton),
            ),
          );
      expect(send().onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('comment_field')), 'Hi');
      await tester.pump();
      expect(send().onPressed, isNotNull);
    });

    testWidgets('submits trimmed text once and clears the field',
        (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentComposer(onSubmit: submitted.add)),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('comment_field')),
        '  hello  ',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Post comment'));
      await tester.pump();

      expect(submitted, ['hello']);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('comment_field')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('whitespace only is never submitted', (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CommentComposer(onSubmit: submitted.add)),
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('comment_field')), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      expect(submitted, isEmpty);
    });
  });
}
