/// 「前回の成績」のヒント（目標やテストを登録するときに表示）
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'grade.dart';
import 'grade_repository.dart';

/// その科目のいちばん新しい成績（なければ null）
(Exam, GradeEntry)? latestGradeFor(List<Exam> exams, String subject) {
  final h = subjectHistory(exams, subject);
  return h.isEmpty ? null : h.last;
}

/// 例：前回 後期中間試験（11/25）82/100点・平均65・偏差値61・12位
String gradeHintText(Exam ex, GradeEntry e) => [
  '前回 ${ex.title}（${ex.date.month}/${ex.date.day}）'
      '${numText(e.score)}/${numText(e.max)}点',
  if (e.average != null) '平均${numText(e.average!)}',
  if (e.deviation != null)
    '偏差値${e.isDeviationEstimated ? '約' : ''}${numText(e.deviation!)}',
  if (e.rank != null) '${e.rank}位',
].join('・');

class LastGradeHint extends StatefulWidget {
  const LastGradeHint({super.key, required this.subject});

  final String subject;

  @override
  State<LastGradeHint> createState() => _LastGradeHintState();
}

class _LastGradeHintState extends State<LastGradeHint> {
  late final _stream = GradeRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  ).watch();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<List<Exam>>(
      stream: _stream,
      builder: (context, snap) {
        final last = latestGradeFor(snap.data ?? const [], widget.subject);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(Icons.history, size: 16, color: cs.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  last == null
                      ? '${widget.subject} の成績はまだ記録がありません'
                      : '参考：${gradeHintText(last.$1, last.$2)}',
                  style: TextStyle(color: cs.outline, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
