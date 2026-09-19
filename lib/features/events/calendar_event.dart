/// 予定のデータ
library;

/// 予定のカテゴリ
enum EventCategory {
  school('学校'),
  club('部活'),
  study('勉強'),
  personal('個人'),
  important('重要'),
  other('その他');

  const EventCategory(this.label);

  /// 画面表示用の名前
  final String label;
}

/// 日付だけにする（時刻を切り捨てる）
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 予定1件
class CalendarEvent {
  const CalendarEvent({
    this.id,
    required this.title,
    required this.start,
    required this.end,
    this.isAllDay = false,
    this.location,
    this.memo,
    this.category = EventCategory.other,
  });

  /// Firestore の ID（まだ保存していない予定は null）
  final String? id;

  final String title;

  /// 開始日時（終日の予定は、開始日の 0:00）
  final DateTime start;

  /// 終了日時（終日の予定は、最終日の 0:00。最終日を含む）
  final DateTime end;

  final bool isAllDay;
  final String? location;
  final String? memo;
  final EventCategory category;

  /// その日に表示する予定か
  bool occursOn(DateTime date) {
    final dayStart = _day(date);
    final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);

    if (isAllDay) {
      return !dayStart.isBefore(_day(start)) && !dayStart.isAfter(_day(end));
    }
    // 時刻のある予定：その日の 0:00〜24:00 と少しでも重なるか
    return start.isBefore(dayEnd) && end.isAfter(dayStart);
  }

  /// 入力内容の確認（問題がなければ null、あればメッセージ）
  String? validate() {
    if (title.trim().isEmpty) return 'タイトルを入力してください';
    if (isAllDay) {
      if (_day(end).isBefore(_day(start))) {
        return '終了日は開始日と同じか、それより後にしてください';
      }
    } else if (!end.isAfter(start)) {
      return '終了時刻は開始時刻より後にしてください';
    }
    return null;
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end,
    bool? isAllDay,
    String? location,
    String? memo,
    EventCategory? category,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      memo: memo ?? this.memo,
      category: category ?? this.category,
    );
  }
}
