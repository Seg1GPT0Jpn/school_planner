/// グループ一覧 ― 参加しているグループを見る・作る・招待コードで参加する
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../review/review_widgets.dart';
import 'group.dart';
import 'group_detail_page.dart';
import 'group_repository.dart';

void openGroups(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const GroupsHubPage()));
}

class GroupsHubPage extends StatefulWidget {
  const GroupsHubPage({super.key});

  @override
  State<GroupsHubPage> createState() => _GroupsHubPageState();
}

class _GroupsHubPageState extends State<GroupsHubPage> {
  late final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _repository = GroupRepository(uid: _uid);

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('グループを作る'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例：留守番ど / 3年A組'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('作る'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    final id = await _repository.create(name);
    if (mounted) openGroupDetail(context, groupId: id);
  }

  Future<void> _joinGroup() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('招待コードで参加'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: '例：AB12CD'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('参加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;
    final group = await _repository.joinByCode(code);
    if (!mounted) return;
    if (group == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('そのコードのグループは見つかりませんでした')));
      return;
    }
    openGroupDetail(context, groupId: group.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('グループ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: '招待コードで参加',
            onPressed: _joinGroup,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Group>>(
        stream: _repository.watchMyGroups(),
        builder: (context, snapshot) {
          final groups = snapshot.data ?? const <Group>[];
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Faint('まだグループに入っていません'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _createGroup,
                      icon: const Icon(Icons.add),
                      label: const Text('グループを作る'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _joinGroup,
                      icon: const Icon(Icons.qr_code),
                      label: const Text('招待コードで参加する'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  final g = groups[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(g.name),
                      subtitle: Text('メンバー ${g.memberCount}人'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openGroupDetail(context, groupId: g.id),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
