/// 自然文からの予定かんたん入力（すべてルールベース・外部AIは使わない）
///
/// 「明日15時から16時 数学の宿題」のような一文から、日付・時刻・タイトルを
/// できる範囲で読み取り、予定の「下書き」を作る。読み取りは完璧ではないので、
/// 必ず画面上で確認・修正してから保存する前提（この関数自体は保存しない）。
library;

/// 時・分だけを持つ軽量な値（Flutter に依存しない）
class TimeOfDayValue {
  const TimeOfDayValue(this.hour, this.minute);
  final int hour;
  final int minute;
}

class ParsedSchedule {
  const ParsedSchedule({
    required this.title,
    required this.date,
    this.startTime,
    this.endTime,
    this.dateGuessed = false,
    this.notes = const [],
  });

  final String title;

  /// 日付だけ（時刻は 0:00）。文中に見つからなければ今日。
  final DateTime date;
  final TimeOfDayValue? startTime;
  final TimeOfDayValue? endTime;

  /// 日付が文中に見つからず、今日を仮定した場合 true
  final bool dateGuessed;

  /// ユーザーに確認してほしいこと（読み取れなかった点など）
  final List<String> notes;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

const _weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];

TimeOfDayValue? _parseClock(String h, String? m) {
  final hour = int.tryParse(h);
  if (hour == null || hour < 0 || hour > 23) return null;
  final minute = (m == null || m.isEmpty) ? 0 : int.tryParse(m);
  if (minute == null || minute < 0 || minute > 59) return null;
  return TimeOfDayValue(hour, minute);
}

ParsedSchedule parseScheduleText(String input, {required DateTime now}) {
  var text = input.trim();
  final notes = <String>[];
  final today = _day(now);

  var date = today;
  var dateGuessed = true;

  // 1) 明示的な日付（9/25、9月25日、25日 など）
  final explicitDate = RegExp(r'(?:(\d{1,2})月)?(\d{1,2})日|(\d{1,2})/(\d{1,2})');
  final dm = explicitDate.firstMatch(text);
  if (dm != null) {
    int month;
    int day;
    if (dm.group(2) != null) {
      month = dm.group(1) != null ? int.parse(dm.group(1)!) : today.month;
      day = int.parse(dm.group(2)!);
    } else {
      month = int.parse(dm.group(3)!);
      day = int.parse(dm.group(4)!);
    }
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      var candidate = DateTime(today.year, month, day);
      // 2か月以上前の日付になってしまう場合は、来年のことと見なす
      if (candidate.isBefore(today.subtract(const Duration(days: 60)))) {
        candidate = DateTime(today.year + 1, month, day);
      }
      date = candidate;
      dateGuessed = false;
      text = text.replaceRange(dm.start, dm.end, ' ');
    }
  } else {
    // 2) 相対日付のことば
    const relWords = <String, int>{
      '今日': 0,
      '本日': 0,
      '明後日': 2,
      'あさって': 2,
      '明日': 1,
      'あす': 1,
      'あした': 1,
    };
    String? matchedWord;
    for (final w in relWords.keys) {
      if (text.contains(w)) {
        matchedWord = w;
        break;
      }
    }
    if (matchedWord != null) {
      date = today.add(Duration(days: relWords[matchedWord]!));
      dateGuessed = false;
      text = text.replaceFirst(matchedWord, ' ');
    } else {
      // 3) 曜日（来週◯曜日 / ◯曜日）
      final weekdayMatch = RegExp(r'(来週)?(月|火|水|木|金|土|日)曜日?').firstMatch(text);
      if (weekdayMatch != null) {
        final nextWeek = weekdayMatch.group(1) != null;
        final targetIdx = _weekdayNames.indexOf(weekdayMatch.group(2)!);
        var delta = (targetIdx - (today.weekday - 1)) % 7;
        if (nextWeek) delta += 7;
        date = today.add(Duration(days: delta));
        dateGuessed = false;
        text = text.replaceRange(weekdayMatch.start, weekdayMatch.end, ' ');
      }
    }
  }

  if (dateGuessed) {
    notes.add('日付が読み取れなかったので、今日の予定として入力しています');
  }

  // 4) 時刻（範囲があれば優先）
  TimeOfDayValue? start;
  TimeOfDayValue? end;

  final rangeColon = RegExp(
    r'(\d{1,2}):(\d{2})\s*(?:[〜~\-−]|から)\s*(\d{1,2}):(\d{2})',
  );
  final rangeKanji = RegExp(
    r'(\d{1,2})時(?:(\d{1,2})分)?\s*(?:[〜~\-−]|から)\s*(\d{1,2})時(?:(\d{1,2})分)?',
  );
  final singleColon = RegExp(r'(\d{1,2}):(\d{2})');
  final singleKanji = RegExp(r'(\d{1,2})時(?:(\d{1,2})分|(半))?');

  final rc = rangeColon.firstMatch(text);
  final rk = rangeKanji.firstMatch(text);
  if (rc != null) {
    start = _parseClock(rc.group(1)!, rc.group(2));
    end = _parseClock(rc.group(3)!, rc.group(4));
    text = text.replaceRange(rc.start, rc.end, ' ');
  } else if (rk != null) {
    start = _parseClock(rk.group(1)!, rk.group(2));
    end = _parseClock(rk.group(3)!, rk.group(4));
    text = text.replaceRange(rk.start, rk.end, ' ');
  } else {
    final sc = singleColon.firstMatch(text);
    final sk = singleKanji.firstMatch(text);
    if (sc != null) {
      start = _parseClock(sc.group(1)!, sc.group(2));
      text = text.replaceRange(sc.start, sc.end, ' ');
    } else if (sk != null) {
      final minuteStr = sk.group(2) ?? (sk.group(3) != null ? '30' : null);
      start = _parseClock(sk.group(1)!, minuteStr);
      text = text.replaceRange(sk.start, sk.end, ' ');
    }
  }

  if (start == null) {
    notes.add('時刻が読み取れなかったので、終日の予定にしています');
  } else if (end == null) {
    notes.add('終了時刻が読み取れなかったので、開始の1時間後にしています');
  }

  // 5) 残った文字列からタイトルを組み立てる
  var title = text
      .replaceAll(RegExp(r'[、。,.]'), ' ')
      .trim();
  title = title.replaceAll(RegExp(r'^(に|の|は|を)\s*'), '');
  title = title.replaceAll(RegExp(r'\s*(に|の|は|を|から|まで)$'), '');
  title = title.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  if (title.isEmpty) title = '（無題の予定）';

  return ParsedSchedule(
    title: title,
    date: date,
    startTime: start,
    endTime: end,
    dateGuessed: dateGuessed,
    notes: notes,
  );
}
