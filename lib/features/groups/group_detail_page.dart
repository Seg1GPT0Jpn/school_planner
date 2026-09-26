/// グループの中身 ― お知らせ・共有ToDo・招待コード・メンバー
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../review/review_widgets.dart';
import 'group.dart';
import 'group_repository.dart';

void openGroupDetail(BuildContext context, {required String groupId}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => GroupDetailPage(groupId: groupId),
    ),
  );
}

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  late final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _repository = GroupRepository(uid: _uid);
  final _inputController = TextEditingController();
  GroupItemType _newType = GroupItemType.announcement;
  bool _indexChecked = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final name = FirebaseAuth.instance.currentUser?.displayName;
    await _repository.addItem(
      widget.groupId,
      type: _newType,
      text: text,
      authorName: name,
    );
    _inputController.clear();
  }

  Future<void> _shareInviteCode(Group g) async {
    await Clipboard.setData(ClipboardData(text: g.inviteCode));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('招待コード「${g.inviteCode}」をコピーしました')),
      );
    }
  }

  Future<void> _confirmLeaveOrDelete(Group g) async {
    final isOwner = g.isOwner(_uid);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(g.name),
        content: Text(isOwner ? 'このグループを削除しますか？' : 'このグループから抜けますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, isOwner ? 'delete' : 'leave'),
            child: Text(isOwner ? '削除' : '抜ける'),
          ),
        ],
      ),
    );
    if (action == 'delete') {
      await _repository.delete(widget.groupId);
    } else if (action == 'leave') {
      await _repository.leave(widget.groupId);
    }
    if (mounted && action != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Group?>(
      stream: _repository.watchGroup(widget.groupId),
      builder: (context, groupSnap) {
        final group = groupSnap.data;
        if (group != null && !_indexChecked && group.isOwner(_uid)) {
          _indexChecked = true;
          // 招待コードの対応表より前に作られたグループなら、ここで登録しておく
          _repository.ensureInviteCodeIndexed(group);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(group?.name ?? 'グループ'),
            actions: [
              if (group != null)
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: '招待コードをコピー',
                  onPressed: () => _shareInviteCode(group),
                ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: group == null
                    ? null
                    : () => _confirmLeaveOrDelete(group),
              ),
            ],
          ),
          body: group == null
              ? const Center(child: CircularProgressIndicator())
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(
                            children: [
                              const Icon(Icons.groups_outlined, size: 18),
                              const SizedBox(width: 6),
                              Text('メンバー ${group.memberCount}人'),
                              const Spacer(),
                              const Icon(Icons.vpn_key_outlined, size: 16),
                              const SizedBox(width: 4),
                              SelectableText(
                                group.inviteCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Expanded(
                          child: StreamBuilder<List<GroupItem>>(
                            stream: _repository.watchItems(widget.groupId),
                            builder: (context, itemSnap) {
                              final items =
                                  itemSnap.data ?? const <GroupItem>[];
                              if (items.isEmpty) {
                                return const Center(
                                  child: Faint('お知らせや共有ToDoは、まだありません'),
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: items.length,
                                itemBuilder: (context, i) {
                                  final it = items[i];
                                  final isTodo =
                                      it.type == GroupItemType.todo;
                                  return ListTile(
                                    leading: isTodo
                                        ? Checkbox(
                                            value: it.done,
                                            onChanged: (v) =>
                                                _repository.setItemDone(
                                                  widget.groupId,
                                                  it.id,
                                                  v ?? false,
                                                ),
                                          )
                                        : const Icon(
                                            Icons.campaign_outlined,
                                          ),
                                    title: Text(
                                      it.text,
                                      style: isTodo && it.done
                                          ? const TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            )
                                          : null,
                                    ),
                                    subtitle: it.authorName == null
                                        ? null
                                        : Text(it.authorName!),
                                    trailing:
                                        it.authorUid == _uid
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                            ),
                                            onPressed: () => _repository
                                                .deleteItem(
                                                  widget.groupId,
                                                  it.id,
                                                ),
                                          )
                                        : null,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              SegmentedButton<GroupItemType>(
                                segments: const [
                                  ButtonSegment(
                                    value: GroupItemType.announcement,
                                    icon: Icon(
                                      Icons.campaign_outlined,
                                      size: 16,
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: GroupItemType.todo,
                                    icon: Icon(
                                      Icons.check_box_outlined,
                                      size: 16,
                                    ),
                                  ),
                                ],
                                selected: {_newType},
                                onSelectionChanged: (s) =>
                                    setState(() => _newType = s.first),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _inputController,
                                  decoration: InputDecoration(
                                    hintText: _newType ==
                                            GroupItemType.announcement
                                        ? 'お知らせを入力'
                                        : '共有ToDoを入力',
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (_) => _addItem(),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _addItem,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
