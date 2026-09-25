import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../timetable/timetable_repository.dart';
import 'school_test_repository.dart';
import 'weekly_lesson_test.dart';

SchoolTestRepository _repo() =>
    SchoolTestRepository(uid: FirebaseAuth.instance.currentUser!.uid);

/// 一覧に出す説明（例：ECⅠ・9/28の週 1201〜・100ずつ・2300まで）
String weeklyRuleSummary(WeeklyLessonTestRule r) => [
  r.subject,
  if (r.startDate != null) '${formatDateJa(r.startDate!)}の週から',
  '${formatDateJa(r.baseWeekDate)}の週が ${r.baseRangeStart}〜',
  '${r.rangeStep}ずつ',
  r.endNumber == null ? '終わりなし' : '${r.endNumber}まで',
  if (r.weekday != null) '毎週${_weekdayLabels[r.weekday! - 1]}曜日',
].join('・');

const _weekdayLabels = ['月', '火', '水', '木', '金'];

/// 毎週の単語テスト（LEAP・鉄壁など）の一覧
class WeeklyRulesPage extends StatefulWidget {
  const WeeklyRulesPage({super.key});

  @override
  State<WeeklyRulesPage> createState() => _WeeklyRulesPageState();
}

class _WeeklyRulesPageState extends State<WeeklyRulesPage> {
  late final _stream = _repo().watchRules();

  @override
  void initState() {
    super.initState();
    _repo().ensureDefaultRules();
  }

  void _open([WeeklyLessonTestRule? r]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => WeeklyRuleEditPage(rule: r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('毎週の単語テスト')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.add),
        label: const Text('追加'),
      ),
      body: StreamBuilder<List<WeeklyLessonTestRule>>(
        stream: _stream,
        builder: (context, snap) {
          final rules = [...snap.data ?? const <WeeklyLessonTestRule>[]]
            ..sort((a, b) => a.baseWeekDate.compareTo(b.baseWeekDate));
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final r in rules)
                ListTile(
                  leading: const Icon(Icons.spellcheck),
                  title: Text(r.title),
                  subtitle: Text(weeklyRuleSummary(r)),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _open(r),
                ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'その週の最初の授業（休講は除く）に、自動で範囲が表示されます。\n'
                  '塾などのミニテスト（EEVI など）は「塾・部活などの定期の予定」の中で設定します。',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 追加・編集
class WeeklyRuleEditPage extends StatefulWidget {
  const WeeklyRuleEditPage({super.key, this.rule});

  final WeeklyLessonTestRule? rule;

  @override
  State<WeeklyRuleEditPage> createState() => _WeeklyRuleEditPageState();
}

class _WeeklyRuleEditPageState extends State<WeeklyRuleEditPage> {
  late final WeeklyLessonTestRule? _r = widget.rule;
  late final _title = TextEditingController(text: _r?.title ?? '');
  late String? _subject = _r?.subject;
  late DateTime _baseWeek = _r?.baseWeekDate ?? DateTime.now();
  late final _start = TextEditingController(text: '${_r?.baseRangeStart ?? 1}');
  late final _step = TextEditingController(text: '${_r?.rangeStep ?? 100}');
  late final _end = TextEditingController(
    text: _r?.endNumber?.toString() ?? '',
  );

  /// 基準の週より前は出さない（新しく追加するときは最初から ON）
  late bool _startFromBase =
      widget.rule == null || widget.rule!.startDate != null;

  /// null = 自動（対象科目の授業が週で最初にある日）。1〜5 = 月〜金に固定
  late int? _weekday = _r?.weekday;

  late final _timetable = TimetableRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  ).watch();
  String? _error;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      return setState(() => _error = 'テストの名前を入力してください');
    }
    if (_subject == null) {
      return setState(() => _error = '科目を選んでください');
    }
    final nav = Navigator.of(context);
    await _repo().saveRule(
      WeeklyLessonTestRule(
        id: _r?.id ?? '',
        subject: _subject!,
        title: _title.text.trim(),
        baseWeekDate: _baseWeek,
        baseRangeStart: int.tryParse(_start.text) ?? 1,
        rangeStep: int.tryParse(_step.text) ?? 100,
        skippedWeeks: _r?.skippedWeeks ?? const <String>{},
        extraWeeks: _r?.extraWeeks ?? const <String>{},
        endNumber: int.tryParse(_end.text),
        startDate: _startFromBase ? _baseWeek : null,
        weekday: _weekday,
      ),
    );
    nav.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('「${_r!.title}」を削除しますか？'),
        content: const Text('カレンダーやホームにこのテストが出なくなります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final nav = Navigator.of(context);
    await _repo().deleteRule(_r!.id);
    nav.pop();
  }

  Widget _num(TextEditingController c, String label, {String? hint}) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, helperText: hint),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_r == null ? '単語テストを追加' : '単語テストを編集'),
        actions: [
          if (_r != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '削除',
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: StreamBuilder<TimetableData>(
        stream: _timetable,
        builder: (context, ts) {
          final subjects = [
            ...{
              for (final s in ts.data?.subjects ?? const []) s.name,
              ?_subject,
            },
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (final p in const [
                    'LEAP単語テスト',
                    '鉄壁単語テスト',
                    '単語テスト',
                    '古文単語テスト',
                  ])
                    ActionChip(
                      label: Text(p),
                      onPressed: () => setState(() => _title.text = p),
                    ),
                ],
              ),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'テストの名前'),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                value: _subject,
                hint: const Text('どの科目の授業で行うか'),
                items: [
                  for (final s in subjects)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _subject = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _baseWeek,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035, 12, 31),
                      );
                      if (d != null) setState(() => _baseWeek = d);
                    },
                    child: Text(formatDateJa(_baseWeek)),
                  ),
                  const Text('の週の範囲が'),
                ],
              ),
              _num(_start, '始まりの番号（例：1）'),
              _num(_step, '1回で進む数（例：100）'),
              _num(_end, '最後の番号（例：1900）', hint: '空にすると終わりなし'),
              const SizedBox(height: 12),
              const Text('テストを行う曜日'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('自動'),
                    selected: _weekday == null,
                    onSelected: (_) => setState(() => _weekday = null),
                  ),
                  for (var i = 0; i < _weekdayLabels.length; i++)
                    ChoiceChip(
                      label: Text('${_weekdayLabels[i]}曜日'),
                      selected: _weekday == i + 1,
                      onSelected: (_) => setState(() => _weekday = i + 1),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _weekday == null
                    ? '「自動」は、その週で対象科目の授業が最初にある日にテストを行います。'
                    : '毎週${_weekdayLabels[_weekday! - 1]}曜日にテストを行います'
                          '（その日が休講・授業なしの場合はその週はテストなし）。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('この週から始める'),
                subtitle: const Text('OFF にすると、前の週にも逆算した範囲を出します'),
                value: _startFromBase,
                onChanged: (v) => setState(() => _startFromBase = v),
              ),
              const SizedBox(height: 8),
              Text(
                'その週の最初の授業（休講は除く）でテスト。'
                '「この週はなし」にした週は範囲が進みません。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
