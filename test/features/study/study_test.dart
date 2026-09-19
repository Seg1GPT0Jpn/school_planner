import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/study/study.dart';

void main() {
  final list = [
    StudySession(subject: '数学Ⅰ', start: DateTime(2026, 9, 20, 10), minutes: 45),
    StudySession(subject: 'ECⅠ', start: DateTime(2026, 9, 20, 20), minutes: 30),
    StudySession(subject: '数学Ⅰ', start: DateTime(2026, 9, 18, 21), minutes: 60),
    StudySession(start: DateTime(2026, 9, 12), minutes: 15),
  ];

  test('週の始まりは日曜日', () {
    expect(weekStart(DateTime(2026, 9, 23)), DateTime(2026, 9, 20));
    expect(weekStart(DateTime(2026, 9, 20)), DateTime(2026, 9, 20));
  });

  test('今日・期間の合計', () {
    expect(
      totalMinutes(list, DateTime(2026, 9, 20), DateTime(2026, 9, 21)),
      75,
    );
    expect(
      totalMinutes(list, DateTime(2026, 9, 1), DateTime(2026, 10, 1)),
      150,
    );
  });

  test('科目ごと（多い順・科目なしは「その他」）', () {
    final r = minutesBySubject(
      list,
      DateTime(2026, 9, 1),
      DateTime(2026, 10, 1),
    );
    expect(r.first.key, '数学Ⅰ');
    expect(r.first.value, 105);
    expect(r.last.key, 'その他');
  });

  test('7日間の毎日（古い順）', () {
    final d = dailyMinutes(list, DateTime(2026, 9, 20), 7);
    expect(d.length, 7);
    expect(d.last, 75);
    expect(d[4], 60); // 9/18
  });

  test('時間の表示', () {
    expect(formatMinutes(45), '45分');
    expect(formatMinutes(60), '1時間');
    expect(formatMinutes(90), '1時間30分');
  });
}
