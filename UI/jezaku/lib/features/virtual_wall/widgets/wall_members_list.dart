import 'package:material_ui/material_ui.dart';

class WallMembersList extends StatelessWidget {
  const WallMembersList({
    required this.memberCount,
    required this.memberCountLabel,
    super.key,
  });

  final int memberCount;
  final String memberCountLabel;

  @override
  Widget build(BuildContext context) {
    final count = memberCount.clamp(4, 12);

    return ListView.builder(
      itemCount: count + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return ListTile(
            leading: const Icon(Icons.group_outlined),
            title: Text(memberCountLabel),
          );
        }

        final memberIndex = index - 1;
        return ListTile(
          leading: CircleAvatar(child: Text('M${memberIndex + 1}'[0])),
          title: Text('Member ${memberIndex + 1}'),
          subtitle: Text(memberIndex == 0 ? 'Owner' : 'Contributor'),
          trailing: memberIndex == 0 ? const Icon(Icons.verified) : null,
        );
      },
    );
  }
}
