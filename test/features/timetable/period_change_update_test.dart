import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/timetable/timetable_models.dart';
import 'package:school_planner/features/timetable/timetable_repository.dart';

void main() {
  test('変更がない日に、1限の科目を設定する', () {
    final result = TimetableRepository.updatedChanges(
      null,
      1,
      const PeriodChange.replace(period: 1, subject: '数学Ⅰ'),
    );
    expect(result.length, 1);
    expect(result.single['type'], 'replace');
    expect(result.single['period'], 1);
    expect(result.single['subject'], '数学Ⅰ');
  });

  test('同じ時限の変更は、新しいものに置き換わる（ほかの時限はそのまま）', () {
    final existing = [
      {'type': 'replace', 'period': 1, 'subject': '数学Ⅰ'},
      {'type': 'replace', 'period': 2, 'subject': '化学基礎'},
    ];
    final result = TimetableRepository.updatedChanges(
      existing,
      1,
      const PeriodChange.replace(period: 1, subject: '公共'),
    );
    expect(result.length, 2);
    expect(result.firstWhere((c) => c['period'] == 1)['subject'], '公共');
    expect(result.firstWhere((c) => c['period'] == 2)['subject'], '化学基礎');
  });

  test('「元に戻す」（null）で、その時限の変更だけが消える', () {
    final existing = [
      {'type': 'cancel', 'period': 3},
      {'type': 'replace', 'period': 4, 'subject': '体育'},
    ];
    final result = TimetableRepository.updatedChanges(existing, 3, null);
    expect(result.length, 1);
    expect(result.single['period'], 4);
  });
}
