/// 学校イベント ― 行事に関係する予定・ToDo・持ち物・目標・ふり返りをまとめて見る
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../belongings/belongings.dart';
import '../events/calendar_event.dart';
import '../recurring/recurring_test_rule.dart';
import '../school_tests/school_test.dart';
import '../settings/settings_scope.dart';
import '../todo/todo_page.dart';
import '../todo/todo_repository.dart';
import 'review_repository.dart';
import 'review_widgets.dart';
import 'school_event.dart';
import 'tsuzuri_data.dart';

const _wd = ['月', '火', '水', '木', '金', '土', '日'];

String _two(int n) => n.toString().padLeft(2, '0');

/// 手で登録した「学校行事」から開く
void openSchoolEventFromTest(BuildContext context, SchoolTest t) => _open(
  context,
  SchoolEventPage(
    eventKey: 't_${t.id}',
    title: t.displayTitle,
    date: t.date,
    memo: t.memo,
  ),
);

/// カレンダーの予定から開く
void openSchoolEventFromEvent(BuildContext context, CalendarEvent e) {
  final d = e.start;
  final key = e.id != null
      ? 'e_${e.id}'
      : 'e_${d.year}-${_two(d.month)}-${_two(d.day)}_'
            '${e.title.replaceAll('/', '／').replaceAll(RegExp(r'\s+'), '_')}';
  _open(
    context,
    SchoolEventPage(
      eventKey: key,
      title: e.title,
      date: e.start,
      endDate: e.end,
      isAllDay: e.isAllDay,
      location: e.location,
      memo: e.memo,
      self: e,
    ),
  );
}

void _open(BuildContext context, Widget page) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => page));

class SchoolEventPage extends StatefulWidget {
  const SchoolEventPage({
    super.key,
    required this.eventKey,
    required this.title,
    required this.date,
    this.endDate,
    this.isAllDay = true,
    this.location,
    this.memo,
    this.self,
  });

  /// 関係づける言葉を保存するときの名前
  final String eventKey;

  final String title;
  final DateTime date;
  final DateTime? endDate;
  final bool isAllDay;
  final String? location;
  final String? memo;

  /// カレンダーの予定から開いたとき、その予定（関係する予定から外すため）
  final CalendarEvent? self;

  @override
  State<SchoolEventPage> createState() => _SchoolEventPageState();
}

class _SchoolEventPageState extends State<SchoolEventPage> {
  late final _repo = ReviewRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  );
  late final _keywordStream = _repo.watchEventKeywords(widget.eventKey);

  Future<void> _editKeywords(List<String> current) async {
    final c = TextEditingController(text: current.join(' '));
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('関係づける言葉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: c,
              autofocus: true,
              decoration: const InputDecoration(hintText: '例：合唱 朝練 伴奏'),
            ),
            const SizedBox(height: 8),
            const Text(
              'スペースで区切ります。どれかの言葉が名前やメモに入っている予定・ToDo・目標・ふり返りを集めます。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    c.dispose();
    if (text == null) return;
    final words = parseKeywords(text);
    await _repo.saveEventKeywords(
      widget.eventKey,
      words.isEmpty ? defaultKeywords(widget.title) : words,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学校イベント')),
      body: StreamBuilder<List<String>?>(
        stream: _keywordStream,
        builder: (context, ks) {
          final keywords = ks.data ?? defaultKeywords(widget.title);
          return TsuzuriDataBuilder(
            parts: const {
              DataPart.timetable,
              DataPart.recurring,
              DataPart.todos,
              DataPart.goals,
              DataPart.reflections,
              DataPart.events,
              DataPart.belongings,
            },
            builder: (context, data) => _body(context, data, keywords),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    TsuzuriSnapshot data,
    List<String> keywords,
  ) {
    final settings = SettingsScope.of(context);
    final d = DateTime(widget.date.year, widget.date.month, widget.date.day);
    final from = DateTime(d.year, d.month, d.day - eventLookbackDays);
    final to = DateTime(d.year, d.month, d.day + 1);
    final related = gatherRelated(
      date: d,
      keywords: keywords,
      events: [
        ...data.events,
        ...expandRecurringWithTests(data.recurring, from, to),
      ],
      todos: data.allTodos,
      goals: data.goals,
      reflections: data.reflections,
      self: widget.self,
    );
    final belongings = belongingsFor(
      day: data.timetable!.resolver.resolve(d),
      recurring: data.recurring,
      settings: data.belongings,
    );
    final todoRepo = TodoRepository(
      uid: FirebaseAuth.instance.currentUser!.uid,
    );
    final daysLeft = DateTime.utc(d.year, d.month, d.day)
        .difference(
          DateTime.utc(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        )
        .inDays;
    const gap = SizedBox(height: 12);

    String when() {
      final base = '${d.year}年${d.month}月${d.day}日(${_wd[d.weekday - 1]})';
      if (widget.isAllDay || widget.self == null) return base;
      return '$base ${settings.timeOf(widget.date)}'
          '${widget.endDate == null ? '' : '〜${settings.timeOf(widget.endDate!)}'}';
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            InfoCard(
              title: widget.title,
              icon: Icons.celebration_outlined,
              trailing: Faint(
                daysLeft > 0
                    ? 'あと$daysLeft日'
                    : daysLeft == 0
                    ? '今日'
                    : '${-daysLeft}日前',
              ),
              children: [
                Text(when()),
                if (widget.location != null && widget.location!.isNotEmpty)
                  Text('📍 ${widget.location}'),
                if (widget.memo != null && widget.memo!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Faint(widget.memo!),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final k in keywords)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(k),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _editKeywords(keywords),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('言葉'),
                    ),
                  ],
                ),
                const Faint('この言葉が名前やメモに入っているものを、下に集めています'),
              ],
            ),
            gap,
            InfoCard(
              title: '予定',
              icon: Icons.event_outlined,
              trailing: Faint('${related.events.length}件'),
              children: [
                if (related.events.isEmpty)
                  const Faint('関係する予定はありません（例：「合唱 朝練」のように名前に言葉を入れると出ます）'),
                for (final e in related.events)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Faint(
                            '${e.start.month}/${e.start.day}'
                            '(${_wd[e.start.weekday - 1]})'
                            '${e.isAllDay ? '' : ' ${settings.timeOf(e.start)}'}',
                          ),
                        ),
                        Expanded(child: Text(e.title)),
                      ],
                    ),
                  ),
              ],
            ),
            gap,
            InfoCard(
              title: 'ToDo',
              icon: Icons.check_box_outlined,
              trailing: Faint(
                '${related.todos.where((t) => t.done).length}/${related.todos.length} 完了',
              ),
              children: [
                if (related.todos.isEmpty) const Faint('関係する ToDo はありません'),
                for (final t in related.todos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Checkbox(
                      value: t.done,
                      onChanged: (v) =>
                          todoRepo.save(t.copyWith(done: v ?? false)),
                    ),
                    title: Text(
                      t.title,
                      style: t.done
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            )
                          : null,
                    ),
                    subtitle: t.dueDate == null
                        ? null
                        : Text('${t.dueDate!.month}/${t.dueDate!.day}まで'),
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => TodoEditPage(
                              todo: t,
                              subjects: data.timetable?.subjects ?? const [],
                            ),
                          ),
                        ),
                  ),
              ],
            ),
            gap,
            InfoCard(
              title: 'その日の持ち物',
              icon: Icons.backpack_outlined,
              children: [
                if (belongings.isEmpty) const Faint('この日の持ち物は登録されていません'),
                if (belongings.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final b in belongings)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(b),
                        ),
                    ],
                  ),
              ],
            ),
            gap,
            InfoCard(
              title: '目標',
              icon: Icons.flag_outlined,
              children: [
                if (related.goals.isEmpty) const Faint('関係する目標はありません'),
                for (final g in related.goals)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('「${g.title}」'),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: g.progress,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (related.reflections.isNotEmpty) ...[
              gap,
              InfoCard(
                title: 'ふり返り',
                icon: Icons.edit_note,
                children: [
                  for (final r in related.reflections)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 56,
                            child: Faint('${r.date.month}/${r.date.day}'),
                          ),
                          Expanded(child: Text(r.text)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
