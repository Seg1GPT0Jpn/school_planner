import 'package:material_ui/material_ui.dart';

import 'day_timetable_resolver.dart';
import 'timetable_models.dart';

/// 選んだ操作
enum LessonChangeAction {
  /// 科目を設定する
  setSubject,

  /// 休講にする
  cancel,

  /// 元に戻す（その時限の変更を消す）
  reset,
}

/// ダイアログの結果
class LessonChangeResult {
  const LessonChangeResult(this.action, [this.subject]);

  final LessonChangeAction action;
  final String? subject;
}

/// 授業の科目を1日だけ変える（試験日課の日は、試験科目を設定する）
class LessonChangeDialog extends StatefulWidget {
  const LessonChangeDialog({
    super.key,
    required this.subjects,
    required this.lesson,
    required this.isExamDay,
  });

  final List<Subject> subjects;
  final ResolvedLesson lesson;

  /// 試験日課の日か
  final bool isExamDay;

  @override
  State<LessonChangeDialog> createState() => _LessonChangeDialogState();
}

class _LessonChangeDialogState extends State<LessonChangeDialog> {
  String? _subject;

  @override
  void initState() {
    super.initState();
    _subject = widget.lesson.subject;
  }

  /// すでに変更されている授業か（「元に戻す」を出すかどうか）
  bool get _canReset {
    final status = widget.lesson.status;
    return status == LessonStatus.changed ||
        status == LessonStatus.cancelled ||
        status == LessonStatus.added;
  }

  void _close([LessonChangeResult? result]) =>
      Navigator.of(context).pop(result);

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;

    // 科目の選択肢（一覧にない科目が入っていても表示できるようにする）
    final names = [for (final s in widget.subjects) s.name];
    if (_subject != null && !names.contains(_subject)) names.add(_subject!);

    return AlertDialog(
      title: Text(
        widget.isExamDay
            ? '${lesson.period}限の試験科目'
            : '${lesson.period}限の科目を変更（この日だけ）',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${lesson.start}〜${lesson.end}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          DropdownButton<String>(
            isExpanded: true,
            value: _subject,
            hint: const Text('科目を選んでください'),
            items: [
              for (final name in names)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (value) => setState(() => _subject = value),
          ),
        ],
      ),
      actions: [
        if (_canReset)
          TextButton(
            onPressed: () =>
                _close(const LessonChangeResult(LessonChangeAction.reset)),
            child: const Text('元に戻す'),
          ),
        if (!widget.isExamDay && lesson.status != LessonStatus.cancelled)
          TextButton(
            onPressed: () =>
                _close(const LessonChangeResult(LessonChangeAction.cancel)),
            child: const Text('休講にする'),
          ),
        TextButton(onPressed: () => _close(), child: const Text('キャンセル')),
        FilledButton(
          onPressed: _subject == null
              ? null
              : () => _close(
                  LessonChangeResult(LessonChangeAction.setSubject, _subject),
                ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
