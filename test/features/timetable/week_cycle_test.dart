import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

void main() {
  // 指示書の例：2026年9月7日（月）はⅠ週
  final anchorSep7 = WeekAnchor(
    date: DateTime(2026, 9, 7),
    weekType: WeekType.one,
  );

  group('日付の基本処理', () {
    test('月曜日の求め方（土日はその週の月曜日になる）', () {
      expect(dateKey(mondayOf(DateTime(2026, 9, 9))), '2026-09-07'); // 水
      expect(dateKey(mondayOf(DateTime(2026, 9, 13))), '2026-09-07'); // 日
      expect(dateKey(mondayOf(DateTime(2026, 9, 14))), '2026-09-14'); // 月
    });

    test('dateKey の形式', () {
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('テスト1〜3：Ⅰ週・Ⅱ週の判定とサイクル', () {
    final calc = WeekCycleCalculator(anchors: [anchorSep7]);

    test('テスト1：基準日の週はⅠ週（月〜日すべて）', () {
      expect(calc.weekTypeFor(DateTime(2026, 9, 7)), WeekType.one);
      expect(calc.weekTypeFor(DateTime(2026, 9, 11)), WeekType.one);
      expect(calc.weekTypeFor(DateTime(2026, 9, 13)), WeekType.one);
    });

    test('テスト2：翌週はⅡ週', () {
      expect(calc.weekTypeFor(DateTime(2026, 9, 14)), WeekType.two);
      expect(calc.weekTypeFor(DateTime(2026, 9, 18)), WeekType.two);
    });

    test('テスト3：Ⅰ→Ⅱ→Ⅰ→Ⅱ のサイクル（指示書の例）', () {
      expect(calc.weekTypeFor(DateTime(2026, 9, 7)), WeekType.one);
      expect(calc.weekTypeFor(DateTime(2026, 9, 14)), WeekType.two);
      expect(calc.weekTypeFor(DateTime(2026, 9, 21)), WeekType.one);
      expect(calc.weekTypeFor(DateTime(2026, 9, 28)), WeekType.two);
    });

    test('基準日より前は判定できない（null）', () {
      expect(calc.weekTypeFor(DateTime(2026, 9, 6)), isNull);
    });

    test('基準日が1つもなければ判定できない（null）', () {
      final empty = WeekCycleCalculator(anchors: []);
      expect(empty.weekTypeFor(DateTime(2026, 9, 7)), isNull);
    });
  });

  group('テスト4：基準日の変更・複数の基準日', () {
    test('基準日を1週ずらすと、サイクルも1週ずれる', () {
      final calc = WeekCycleCalculator(
        anchors: [
          WeekAnchor(date: DateTime(2026, 9, 14), weekType: WeekType.one),
        ],
      );
      expect(calc.weekTypeFor(DateTime(2026, 9, 14)), WeekType.one);
      expect(calc.weekTypeFor(DateTime(2026, 9, 21)), WeekType.two);
      expect(calc.weekTypeFor(DateTime(2026, 9, 28)), WeekType.one);
    });

    test('対象日より前で一番新しい基準日が使われる', () {
      // 冬休み明けに「2027年1月12日（火）の週はⅡ週」と新しい基準日を追加
      final calc = WeekCycleCalculator(
        anchors: [
          WeekAnchor(date: DateTime(2027, 1, 12), weekType: WeekType.two),
          anchorSep7, // 順番がバラバラでも正しく動くことも確認
        ],
      );

      // 冬休み前は、9月7日の基準日で判定（9/7から15週後 → Ⅱ週）
      expect(calc.weekTypeFor(DateTime(2026, 12, 21)), WeekType.two);

      // 1月11日の週からは、新しい基準日で判定（火曜指定でも週単位で扱う）
      expect(calc.weekTypeFor(DateTime(2027, 1, 11)), WeekType.two);
      expect(calc.weekTypeFor(DateTime(2027, 1, 18)), WeekType.one);
      expect(calc.weekTypeFor(DateTime(2027, 1, 25)), WeekType.two);
    });
  });

  group('週単位override', () {
    // 9/21〜25 の週だけ Ⅱ週扱い（通常はⅠ週）
    final calc = WeekCycleCalculator(
      anchors: [anchorSep7],
      weekOverrides: {'2026-09-21': WeekType.two},
    );

    test('override した週は、その設定が優先される', () {
      expect(calc.weekTypeFor(DateTime(2026, 9, 21)), WeekType.two);
      expect(calc.weekTypeFor(DateTime(2026, 9, 25)), WeekType.two);
      expect(calc.isOverridden(DateTime(2026, 9, 23)), isTrue);
    });

    test('自動判定だけを見ると、本来はⅠ週', () {
      expect(calc.autoWeekTypeFor(DateTime(2026, 9, 21)), WeekType.one);
    });

    test('翌週からは通常のサイクルに戻る（サイクルはずれない）', () {
      expect(calc.weekTypeFor(DateTime(2026, 9, 28)), WeekType.two);
      expect(calc.weekTypeFor(DateTime(2026, 10, 5)), WeekType.one);
      expect(calc.isOverridden(DateTime(2026, 9, 28)), isFalse);
    });

    test('前の週にも影響しない', () {
      expect(calc.weekTypeFor(DateTime(2026, 9, 14)), WeekType.two);
    });
  });
}
