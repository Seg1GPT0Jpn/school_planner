/// 小テスト・定期テスト・提出物・学校行事など（手で登録するもの）
library;

import '../timetable/school_periods.dart';

/// 種類
enum SchoolTestKind {
  quiz('小テスト'),
  regularExam('定期テスト'),
  mockExam('模試'),
  assignment('提出物'),
  homework('宿題'),
  report('レポート'),
  schoolEvent('学校行事');

  const SchoolTestKind(this.label);

  /// 画面表示用の名前
  final String label;

  /// テストの仲間か（ホームの「近いテスト」に出すもの）
  bool get isTest =>
      this == SchoolTestKind.quiz ||
      this == SchoolTestKind.regularExam ||
      this == SchoolTestKind.mockExam;
}

/// 科目ごとの、よくある小テストの名前（選ぶだけで入力できるようにする）
const Map<String, List<String>> quizPresets = {
  '現代の国語': ['漢字テスト', '単語テスト'],
  '言語文化': ['単語テスト', '文法テスト'],
};

/// 日付だけにする
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 1件分
class SchoolTest {
  const SchoolTest({
    this.id,
    required this.kind,
    required this.title,
    required this.date,
    this.subject,
    this.period,
    this.startTime,
    this.scope,
    this.memo,
  });

  /// Firestore の ID（まだ保存していないものは null）
  final String? id;

  final SchoolTestKind kind;

  /// 名前（例：漢字テスト）
  final String title;

  /// 日付
  final DateTime date;

  /// 科目（例：現代の国語）。学校行事などでは null
  final String? subject;

  /// 何時間目の授業で行うか（わからなければ null）
  final int? period;

  /// 開始時刻（授業と関係ない行事・模試など）
  final ClockTime? startTime;

  /// 範囲（例：p.20〜35、No.1201〜1300）
  final String? scope;

  final String? memo;

  /// 画面に出す名前（例：現代の国語 漢字テスト）
  String get displayTitle => subject == null ? title : '$subject $title';

  /// 授業のブロックに出す短い名前（例：漢字テスト p.20〜35）
  String get lessonLabel => scope == null ? title : '$title $scope';

  /// その日のものか
  bool isOn(DateTime day) => _day(date) == _day(day);

  /// 入力内容の確認（問題がなければ null）
  String? validate() {
    if (title.trim().isEmpty) return '名前を入力してください';
    if (period != null && (period! < 1 || period! > 5)) {
      return '時限は1〜5で指定してください';
    }
    return null;
  }
}
