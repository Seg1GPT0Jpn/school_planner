import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import '../school_tests/school_test.dart';
import '../timetable/timetable_repository.dart';
import 'goal_repository.dart';
import 'study_plan.dart';

/// 勉強計画の画面を開く
void openStudyPlan(BuildContext context, SchoolTest test) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => StudyPlanPage(test: test),
    ),
  );
}

/// 定期テスト前の勉強計画を作る
class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({super.key, required this.test});

  final SchoolTest test;

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _timetable = TimetableRepository(uid: _uid).watch();

  int _days = 14;
  int _perDay = 2;

  /// 選んだ科目（null のあいだは「時間割の科目ぜんぶ」）
  List<String>? _chosen;

  Future<void> _save(List<String> items) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await GoalRepository(uid: _uid)
        .saveGoal(studyPlanGoal(widget.test, items, _days));
    messenger.showSnackBar(const SnackBar(content: Text('「目標」に勉強計画を追加しました')));
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.test;
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<TimetableData>(
      stream: _timetable,
      builder: (context, snap) {
        final data = snap.data;
        // 候補：その時期の時間割にある科目
        final all = data == null
            ? <String>[]
            : {for (final s in data.slotsForDate(t.date)) s.subject}.toList();
        final chosen = _chosen ?? all;
        final items = buildStudyPlan(
          examDate: t.date,
          subjects: [
            for (final s in all)
              if (chosen.contains(s)) s,
          ],
          days: _days,
          perDay: _perDay,
        );

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('勉強計画を作る'),
            actions: [
              TextButton(
                onPressed: items.isEmpty ? null : () => _save(items),
                child: const Text('目標に追加'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${t.title}（${formatDateJa(t.date)}）',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const Text('何日前から'),
              const SizedBox(height: 4),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('1週間')),
                  ButtonSegment(value: 10, label: Text('10日')),
                  ButtonSegment(value: 14, label: Text('2週間')),
                  ButtonSegment(value: 21, label: Text('3週間')),
                ],
                selected: {_days},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _days = s.first),
              ),
              const SizedBox(height: 16),
              const Text('1日の科目の数'),
              const SizedBox(height: 4),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1つ')),
                  ButtonSegment(value: 2, label: Text('2つ')),
                  ButtonSegment(value: 3, label: Text('3つ')),
                ],
                selected: {_perDay},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _perDay = s.first),
              ),
              const SizedBox(height: 16),
              const Text('テストに出る科目（タップで外す）'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in all)
                    FilterChip(
                      label: Text(s),
                      selected: chosen.contains(s),
                      onSelected: (on) => setState(() {
                        final next = [...chosen];
                        if (on) {
                          next.add(s);
                        } else {
                          next.remove(s);
                        }
                        _chosen = next;
                      }),
                    ),
                ],
              ),
              const Divider(height: 32),
              Text(
                '計画（チェックリストとして「目標」に入ります）',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Text('科目を1つ以上選んでください', style: TextStyle(color: cs.outline)),
              for (final s in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_box_outline_blank,
                        size: 18,
                        color: cs.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                '作り直すと、前の計画のチェックは消えます。',
                style: TextStyle(color: cs.outline, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
