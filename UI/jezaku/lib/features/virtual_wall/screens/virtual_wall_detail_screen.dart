import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';
import 'package:jejaku/features/virtual_wall/widgets/add_wall_item_dialog.dart';
import 'package:jejaku/features/virtual_wall/widgets/invite_member_dialog.dart';
import 'package:jejaku/features/virtual_wall/widgets/manage_linked_anchors_dialog.dart';
import 'package:jejaku/features/virtual_wall/widgets/wall_members_list.dart';
import 'package:jejaku/features/virtual_wall/widgets/wall_overview_widgets.dart';
import 'package:material_ui/material_ui.dart';

class VirtualWallDetailScreen extends ConsumerWidget {
  const VirtualWallDetailScreen({super.key, required this.wallId});

  final String wallId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wall = _findWall(ref.watch(arWallsProvider));
    final linkedMemories = ref.watch(wallLinkedMemoriesProvider(wallId));
    final availableMemories = ref.watch(nearbyAnchorsProvider);
    if (wall == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Virtual Wall')),
        body: const Center(child: Text('Wall not found')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(wall.title),
          actions: [
            IconButton(
              tooltip: 'Manage linked anchors',
              icon: const Icon(Icons.hub_outlined),
              onPressed: () => _showManageLinkedAnchorsDialog(
                context,
                ref,
                wall,
                availableMemories,
              ),
            ),
            IconButton(
              tooltip: 'Invite members',
              icon: const Icon(Icons.person_add_alt),
              onPressed: () => _showInviteMemberDialog(context, ref, wall),
            ),
            IconButton(
              tooltip: 'QR code',
              icon: const Icon(Icons.qr_code),
              onPressed: () => _showQrCode(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Wall'),
              Tab(text: 'Members'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            WallOverviewTab(
              wall: wall,
              linkedMemories: linkedMemories,
            ),
            WallMembersList(
              memberCount: wall.memberCount,
              memberCountLabel: wall.memberCountLabel,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddItemDialog(context, ref, wall),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _showManageLinkedAnchorsDialog(
    BuildContext context,
    WidgetRef ref,
    ARWall wall,
    List<AnchorMemory> availableMemories,
  ) async {
    final linkedMemoryIds = await showDialog<List<String>>(
      context: context,
      builder: (_) => ManageLinkedAnchorsDialog(
        availableMemories: availableMemories,
        selectedMemoryIds: wall.linkedMemoryIds,
      ),
    );

    if (linkedMemoryIds == null || !context.mounted) {
      return;
    }

    ref.read(arWallsProvider.notifier).updateLinkedMemoryIds(
          wallId: wall.id,
          linkedMemoryIds: linkedMemoryIds,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Linked anchors updated.')),
    );
  }

  ARWall? _findWall(List<ARWall> walls) {
    for (final wall in walls) {
      if (wall.id == wallId) {
        return wall;
      }
    }
    return null;
  }

  void _showQrCode(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Scan to Join'),
          content: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code, size: 160),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showInviteMemberDialog(
    BuildContext context,
    WidgetRef ref,
    ARWall wall,
  ) async {
    final invitee = await showDialog<String>(
      context: context,
      builder: (_) => const InviteMemberDialog(),
    );

    if (invitee == null || !context.mounted) {
      return;
    }

    ref.read(arWallsProvider.notifier).inviteMember(
          wallId: wall.id,
          invitee: invitee,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${invitee.trim()} invited.')),
    );
  }

  Future<void> _showAddItemDialog(
    BuildContext context,
    WidgetRef ref,
    ARWall wall,
  ) async {
    final draft = await showDialog<WallItemDraft>(
      context: context,
      builder: (_) => const AddWallItemDialog(),
    );

    if (draft == null || !context.mounted) {
      return;
    }

    ref.read(arWallsProvider.notifier).addWallItem(
          wallId: wall.id,
          type: draft.type,
          content: draft.content,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${wallItemTypeLabel(draft.type)} added.')),
    );
  }
}
