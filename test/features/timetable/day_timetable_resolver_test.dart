import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/timetable/day_timetable_resolver.dart';
import 'package:school_planner/features/timetable/school_periods.dart';
import 'package:school_planner/features/timetable/timetable_models.dart';
import 'package:school_planner/features/timetable/week_cycle.dart';

// ---- テスト用の通常時間割 ----
// 2026年9月7日（月）の週をⅠ週とする
//   9/7〜  Ⅰ週、9/14〜 Ⅱ週、9/21〜 Ⅰ週、9/28〜 Ⅱ週
List<TimetableSlot> _slots() {
  TimetableSlot s(WeekType w, int wd, int p, String subject) =>
      TimetableSlot(weekType: w, weekday: wd, period: p, subject: subject);

  const one = WeekType.one;
  const two = WeekType.two;
  const mon = DateTime.monday;
  const tue = DateTime.tuesday;
  const wed = DateTime.wednesday;

  return [
    // Ⅰ週・月曜
    s(one, mon, 1, '英語'), s(one, mon, 2, '数学'), s(one, mon, 3, '国語'),
    s(one, mon, 4, '体育'), s(one, mon, 5, '化学'),
    // Ⅱ週・月曜
    s(two, mon, 1, '国語'), s(two, mon, 2, '化学'), s(two, mon, 3, '英語'),
    s(two, mon, 4, '数学'), s(two, mon, 5, '音楽'),
    // Ⅰ週・水曜（4限まで）
    s(one, wed, 1, '数学'), s(one, wed, 2, '英語'), s(one, wed, 3, '理科'),
    s(one, wed, 4, '国語'),
    // Ⅱ週・火曜（指示書の例）
    s(two, tue, 1, '英語'), s(two, tue, 2, '数学'), s(two, tue, 3, '国語'),
    s(two, tue, 4, '体育'), s(two, tue, 5, '情報'),
  ];
}

DayTimetableResolver _resolver({
  List<DayOverride> dayOverrides = const [],
  List<SchoolClosure> closures = const [],
  Map<String, WeekType> weekOverrides = const {},
}) {
  return DayTimetableResolver(
    weekCalculator: WeekCycleCalculator(
      anchors: [WeekAnchor(date: DateTime(2026, 9, 7), weekType: WeekType.one)],
      weekOverrides: weekOverrides,
    ),
    slots: _slots(),
    dayOverrides: dayOverrides,
    closures: closures,
  );
}

List<String?> _subjects(DayTimetable day) =>
    day.lessons.map((l) => l.subject).toList();

void main() {
  group('通常時間割', () {
    test('Ⅰ週・月曜（9/7）：5限まで、標準時刻どおり', () {
      final day = _resolver().resolve(DateTime(2026, 9, 7));
      expect(day.status, DayStatus.school);
      expect(day.weekType, WeekType.one);
      expect(_subjects(day), ['英語', '数学', '国語', '体育', '化学']);
      expect(day.lessons.first.start.toString(), '08:50');
      expect(day.lessons.last.end.toString(), '16:00');
      expect(day.hasChanges, isFalse);
    });

    test('Ⅱ週・月曜（9/14）：Ⅱ週の時間割になる', () {
      final day = _resolver().resolve(DateTime(2026, 9, 14));
      expect(day.weekType, WeekType.two);
      expect(_subjects(day), ['国語', '化学', '英語', '数学', '音楽']);
    });

    test('テスト6：水曜（9/9）は4限まで', () {
      final day = _resolver().resolve(DateTime(2026, 9, 9));
      expect(day.lessons.length, 4);
      expect(_subjects(day), ['数学', '英語', '理科', '国語']);
    });

    test('時間割が未設定の日は「空き」になる（Ⅰ週・火曜 9/8）', () {
      final day = _resolver().resolve(DateTime(2026, 9, 8));
      expect(day.lessons.length, 5);
      expect(day.lessons.every((l) => l.status == LessonStatus.empty), isTrue);
    });

    test('土曜は授業なし', () {
      final day = _resolver().resolve(DateTime(2026, 9, 12));
      expect(day.status, DayStatus.noSchool);
      expect(day.lessons, isEmpty);
    });

    test('基準日より前は「週を判定できない」', () {
      final day = _resolver().resolve(DateTime(2026, 9, 1));
      expect(day.status, DayStatus.weekUnknown);
    });
  });

  group('テスト5：特定日の変更が通常設定より優先される', () {
    // 指示書の例：Ⅱ週・火曜（9/15）だけ変更
    final withOverride = _resolver(
      dayOverrides: [
        DayOverride(
          date: DateTime(2026, 9, 15),
          changes: const [
            PeriodChange.replace(period: 2, subject: '国語'),
            PeriodChange.replace(period: 3, subject: '特別授業'),
            PeriodChange.cancel(period: 5),
          ],
        ),
      ],
    );

    test('変更した時限だけが変わり、状態が付く', () {
      final day = withOverride.resolve(DateTime(2026, 9, 15));
      expect(_subjects(day), ['英語', '国語', '特別授業', '体育', '情報']);
      expect(day.lessons[0].status, LessonStatus.normal);
      expect(day.lessons[1].status, LessonStatus.changed);
      expect(day.lessons[2].status, LessonStatus.changed);
      expect(day.lessons[4].status, LessonStatus.cancelled);
      expect(day.hasChanges, isTrue);
      expect(day.hasDayOverride, isTrue);
    });

    test('ほかの日（翌々週のⅡ週・火曜 9/29）には影響しない', () {
      final day = withOverride.resolve(DateTime(2026, 9, 29));
      expect(_subjects(day), ['英語', '数学', '国語', '体育', '情報']);
      expect(day.hasChanges, isFalse);
    });
  });

  group('テスト9：特定日の変更を解除すると通常に戻る', () {
    test('変更データを消した状態では、通常時間割そのもの', () {
      final day = _resolver().resolve(DateTime(2026, 9, 15));
      expect(_subjects(day), ['英語', '数学', '国語', '体育', '情報']);
      expect(day.hasDayOverride, isFalse);
      expect(day.hasChanges, isFalse);
    });
  });

  group('いろいろな変更', () {
    test('教室だけ変更（教科はそのまま）', () {
      final day = _resolver(
        dayOverrides: [
          DayOverride(
            date: DateTime(2026, 9, 7),
            changes: const [PeriodChange.replace(period: 1, room: '視聴覚室')],
          ),
        ],
      ).resolve(DateTime(2026, 9, 7));
      expect(day.lessons[0].subject, '英語');
      expect(day.lessons[0].room, '視聴覚室');
      expect(day.lessons[0].status, LessonStatus.changed);
    });

    test('2限と4限の入れ替え（時刻はそのまま）', () {
      final day = _resolver(
        dayOverrides: [
          DayOverride(
            date: DateTime(2026, 9, 7),
            changes: const [PeriodChange.swap(period: 2, otherPeriod: 4)],
          ),
        ],
      ).resolve(DateTime(2026, 9, 7));
      expect(_subjects(day), ['英語', '体育', '国語', '数学', '化学']);
      expect(day.lessons[1].start.toString(), '10:10');
      expect(day.lessons[3].start.toString(), '13:30');
    });

    test('水曜に5限を追加すると「追加」扱いで標準時刻が入る', () {
      final day = _resolver(
        dayOverrides: [
          DayOverride(
            date: DateTime(2026, 9, 9),
            changes: const [PeriodChange.replace(period: 5, subject: '特別授業')],
          ),
        ],
      ).resolve(DateTime(2026, 9, 9));
      expect(day.lessons.length, 5);
      expect(day.lessons[4].status, LessonStatus.added);
      expect(day.lessons[4].start.toString(), '14:50');
    });

    test('時間変更（教科はそのまま）', () {
      final day = _resolver(
        dayOverrides: [
          DayOverride(
            date: DateTime(2026, 9, 7),
            changes: const [
              PeriodChange.replace(
                period: 3,
                start: ClockTime(11, 0),
                end: ClockTime(12, 10),
              ),
            ],
          ),
        ],
      ).resolve(DateTime(2026, 9, 7));
      expect(day.lessons[2].subject, '国語');
      expect(day.lessons[2].start.toString(), '11:00');
      expect(day.lessons[2].end.toString(), '12:10');
    });

    test('土曜に授業を入れることもできる', () {
      final day = _resolver(
        dayOverrides: [
          DayOverride(
            date: DateTime(2026, 9, 19),
            changes: const [PeriodChange.replace(period: 1, subject: '土曜講習')],
          ),
        ],
      ).resolve(DateTime(2026, 9, 19));
      expect(day.status, DayStatus.school);
      expect(_subjects(day), ['土曜講習']);
      expect(day.lessons[0].status, LessonStatus.added);
    });
  });

  group('優先順位', () {
    test('休業日は、特定日の変更よりも優先される', () {
      final day = _resolver(
        closures: [
          SchoolClosure(
            start: DateTime(2026, 9, 14),
            end: DateTime(2026, 9, 18),
            title: '臨時休校',
          ),
        ],
        dayOverrides: [
          DayOverride(
            date: DateTime(2026, 9, 15),
            changes: const [PeriodChange.replace(period: 1, subject: '特別授業')],
          ),
        ],
      ).resolve(DateTime(2026, 9, 15));
      expect(day.status, DayStatus.closed);
      expect(day.closureTitle, '臨時休校');
      expect(day.lessons, isEmpty);
    });

    test('休業期間の最終日も休み、翌日からは通常', () {
      final resolver = _resolver(
        closures: [
          SchoolClosure(
            start: DateTime(2026, 9, 14),
            end: DateTime(2026, 9, 18),
            title: '臨時休校',
          ),
        ],
      );
      expect(resolver.resolve(DateTime(2026, 9, 18)).status, DayStatus.closed);
      expect(resolver.resolve(DateTime(2026, 9, 21)).status, DayStatus.school);
    });

    test('週単位override の週は、その週の時間割が使われる', () {
      // 9/21 の週は本来Ⅰ週だが、Ⅱ週扱いにする
      final day = _resolver(weekOverrides: {'2026-09-21': WeekType.two})
          .resolve(DateTime(2026, 9, 21));
      expect(day.weekType, WeekType.two);
      expect(day.isWeekOverridden, isTrue);
      expect(_subjects(day), ['国語', '化学', '英語', '数学', '音楽']);
    });
  });
}
