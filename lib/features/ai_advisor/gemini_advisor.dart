/// 生成AI（Gemini）を使った、ほんとうの「今日のひとこと」
///
/// Firebase AI Logic 経由で Gemini Developer API（無料枠）を呼び出す。
/// 使う前に、Firebase Console の「AI Logic」で Gemini Developer API を
/// 有効化しておく必要がある（設定 ＞ AIアドバイス の説明を参照）。
///
/// 呼び出しに失敗したとき（未設定・オフライン・利用枠超過など）は
/// null を返す。呼び出し側は、その場合なにも表示しない
/// （下に出るルールベースの advisor.dart のアドバイスがフォールバック）。
library;

import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../gamification/gamification.dart';
import '../todo/todo.dart';
import '../workload/workload.dart';
import 'nl_schedule_parser.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

const _weekdayJa = ['月', '火', '水', '木', '金', '土', '日'];

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Gemini に渡す材料（生の予定名などは送らず、件数・要約だけに絞る）
class GeminiAdvisorInput {
  const GeminiAdvisorInput({
    required this.todos,
    required this.weekLoad,
    required this.gamification,
    this.recentMoods = const [],
    this.testsWithin3Days = 0,
  });

  final List<Todo> todos;
  final List<DayLoad> weekLoad;
  final GamificationStats gamification;
  final List<String> recentMoods;
  final int testsWithin3Days;
}

String _buildPrompt(GeminiAdvisorInput input, DateTime now) {
  final today = _day(now);
  final undone = input.todos.where((t) => !t.done).length;
  final overdue = input.todos.where((t) => !t.done && t.isOverdue(today)).length;
  final heavyDays = input.weekLoad.where((d) => d.isHeavy).length;
  final moodSummary = input.recentMoods.isEmpty
      ? '記録なし'
      : input.recentMoods.join(' ');

  return '''
あなたは、高校生向け学習管理アプリ「つづり」の中にいる、やさしいアドバイザーです。
以下のデータだけを見て、今日の一言アドバイスを日本語で1〜2文だけ書いてください。
説教くさくせず、前向きで、実際に役立つ一言にしてください。
絵文字は0〜1個まで。マークダウンや箇条書き、前置きの言葉は使わないでください。
出力はアドバイスの本文だけにしてください。

【データ】
未完了のToDo数: $undone
期限切れのToDo数: $overdue
直近7日の気分の記録: $moodSummary
今週、予定が多い（忙しい）日の数: $heavyDays
3日以内のテスト数: ${input.testsWithin3Days}
現在の連続達成日数: ${input.gamification.currentStreak}
''';
}

/// Gemini にアドバイスを生成してもらう。失敗したら null を返す。
Future<String?> generateAdvisorMessage(
  GeminiAdvisorInput input, {
  DateTime? now,
}) async {
  try {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.8-flash',
    );
    final prompt = _buildPrompt(input, now ?? DateTime.now());
    final response = await model
        .generateContent([Content.text(prompt)])
        .timeout(const Duration(seconds: 15));
    final text = response.text?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  } catch (_) {
    // 未設定・オフライン・利用枠超過など、理由はさまざま。
    // ここでは静かに諦めて、呼び出し側のフォールバックに任せる。
    return null;
  }
}

// ------------------------------------------------------------
// 「サクッと予定入力」用：自然文を Gemini に読み取ってもらう
// ------------------------------------------------------------

/// 応答からJSON部分だけを取り出す（前置きやコードフェンスが付いても拾えるように）
String _extractJson(String text) {
  final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
  return match?.group(0) ?? text;
}

DateTime? _parseDateField(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value.trim());
  if (m == null) return null;
  final month = int.parse(m.group(2)!);
  final day = int.parse(m.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(int.parse(m.group(1)!), month, day);
}

TimeOfDayValue? _parseTimeField(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (m == null) return null;
  final hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2)!);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDayValue(hour, minute);
}

/// 自然文から予定の下書き（タイトル・日付・時刻）を、Gemini に読み取ってもらう。
///
/// うまく読み取れなかったとき（未設定・オフライン・応答の形式が崩れたなど）は
/// null を返す。呼び出し側は null のとき、端末内のルールベースの
/// parseScheduleText（nl_schedule_parser.dart）にフォールバックする。
Future<ParsedSchedule?> parseScheduleWithGemini(
  String input, {
  DateTime? now,
}) async {
  final today = _day(now ?? DateTime.now());
  try {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.8-flash',
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
    final prompt =
        '''
今日の日付は ${_fmtDate(today)}（${_weekdayJa[today.weekday - 1]}曜日）です。
次の文章は、高校生が入力した予定（授業・部活・勉強・提出物など）のメモです。
タイトル・日付・開始時刻・終了時刻を読み取り、次のJSON形式だけで答えてください。
前置き、説明、コードブロックの印（```）は書かないでください。

{"title": "予定のタイトル（短く、文章の言い回しはそのまま活かす）", "date": "YYYY-MM-DD", "startTime": "HH:mm または null", "endTime": "HH:mm または null", "allDay": true または false}

・日付の言葉（今日・明日・来週火曜など）が文中になければ、今日の日付にしてください。
・時刻がまったく読み取れなければ startTime と endTime は null にし、allDay は true にしてください。
・開始時刻だけ分かって終了時刻が分からない場合、endTime は null のままでよいです。

文章: "$input"
''';
    final response = await model
        .generateContent([Content.text(prompt)])
        .timeout(const Duration(seconds: 12));
    final text = response.text?.trim();
    if (text == null || text.isEmpty) return null;

    final decoded = jsonDecode(_extractJson(text));
    if (decoded is! Map) return null;
    final data = decoded;

    final title = (data['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;

    final date = _parseDateField(data['date']) ?? today;
    final start = _parseTimeField(data['startTime']);
    final end = _parseTimeField(data['endTime']);

    final notes = <String>[];
    if (start == null) {
      notes.add('時刻が読み取れなかったので、終日の予定にしています（AI解析）');
    } else if (end == null) {
      notes.add('終了時刻が読み取れなかったので、開始の1時間後にしています（AI解析）');
    }

    return ParsedSchedule(
      title: title,
      date: date,
      startTime: start,
      endTime: end,
      dateGuessed: false,
      notes: notes,
    );
  } catch (_) {
    return null;
  }
}
