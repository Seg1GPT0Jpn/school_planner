/// 日付の表示形式（日本語）
library;

const List<String> _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

/// 曜日の1文字（DateTime.monday → 「月」）
String weekdayLabel(int weekday) => _weekdayLabels[weekday - 1];

/// 「9月19日（土）」の形
String formatDateJa(DateTime date) =>
    '${date.month}月${date.day}日（${weekdayLabel(date.weekday)}）';
