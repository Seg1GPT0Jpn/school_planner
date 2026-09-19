import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/events/calendar_event.dart';

void main() {
  group('その日に表示するか（occursOn）', () {
    test('時刻のある予定：その日だけ', () {
      final e = CalendarEvent(
        title: '部活',
        start: DateTime(2026, 9, 24, 16, 30),
        end: DateTime(2026, 9, 24, 18, 30),
      );
      expect(e.occursOn(DateTime(2026, 9, 24)), isTrue);
      expect(e.occursOn(DateTime(2026, 9, 25)), isFalse);
    });

    test('日付をまたぐ予定：両方の日に表示', () {
      final e = CalendarEvent(
        title: '合宿',
        start: DateTime(2026, 9, 26, 20, 0),
        end: DateTime(2026, 9, 27, 10, 0),
      );
      expect(e.occursOn(DateTime(2026, 9, 26)), isTrue);
      expect(e.occursOn(DateTime(2026, 9, 27)), isTrue);
      expect(e.occursOn(DateTime(2026, 9, 28)), isFalse);
    });

    test('ちょうど 0:00 に終わる予定は、次の日には表示しない', () {
      final e = CalendarEvent(
        title: '夜の練習',
        start: DateTime(2026, 9, 26, 22, 0),
        end: DateTime(2026, 9, 27, 0, 0),
      );
      expect(e.occursOn(DateTime(2026, 9, 27)), isFalse);
    });

    test('終日の予定：開始日〜最終日のすべての日に表示', () {
      final e = CalendarEvent(
        title: '修学旅行',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 3),
        isAllDay: true,
      );
      expect(e.occursOn(DateTime(2026, 9, 30)), isFalse);
      expect(e.occursOn(DateTime(2026, 10, 1)), isTrue);
      expect(e.occursOn(DateTime(2026, 10, 3)), isTrue);
      expect(e.occursOn(DateTime(2026, 10, 4)), isFalse);
    });
  });

  group('入力内容の確認（validate）', () {
    test('タイトルが空ならエラー', () {
      final e = CalendarEvent(
        title: '  ',
        start: DateTime(2026, 9, 24, 9),
        end: DateTime(2026, 9, 24, 10),
      );
      expect(e.validate(), isNotNull);
    });

    test('終了が開始より前ならエラー', () {
      final e = CalendarEvent(
        title: '部活',
        start: DateTime(2026, 9, 24, 18),
        end: DateTime(2026, 9, 24, 17),
      );
      expect(e.validate(), isNotNull);
    });

    test('終日の予定は、同じ日に終わってもOK', () {
      final e = CalendarEvent(
        title: '文化祭',
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 1),
        isAllDay: true,
      );
      expect(e.validate(), isNull);
    });
  });
}
