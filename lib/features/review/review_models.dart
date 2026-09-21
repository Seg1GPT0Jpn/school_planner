/// テストカルテのふり返り・期間のふり返りのデータ
library;

import '../school_tests/upcoming_tests.dart';

/// テストのあとに書くもの（点数とふり返り）
class TestReview {
  const TestReview({
    this.score,
    this.maxScore = 100,
    this.good = '',
    this.bad = '',
    this.improve = '',
    this.next = '',
  });

  /// 点数（まだなら null）
  final num? score;
  final num maxScore;

  /// できたこと
  final String good;

  /// できなかったこと
  final String bad;

  /// 次に直すこと
  final String improve;

  /// 次の目標
  final String next;

  bool get hasText =>
      good.trim().isNotEmpty ||
      bad.trim().isNotEmpty ||
      improve.trim().isNotEmpty ||
      next.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'score': score,
    'maxScore': maxScore,
    'good': good.trim(),
    'bad': bad.trim(),
    'improve': improve.trim(),
    'next': next.trim(),
  };

  static TestReview fromMap(Map<String, dynamic>? m) {
    if (m == null) return const TestReview();
    String t(String k) => m[k] is String ? m[k] as String : '';
    return TestReview(
      score: m['score'] is num ? m['score'] as num : null,
      maxScore: m['maxScore'] is num ? m['maxScore'] as num : 100,
      good: t('good'),
      bad: t('bad'),
      improve: t('improve'),
      next: t('next'),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// テスト1つを見分ける名前（保存に使う）
///
/// 手で登録したテストはその ID、自動で出るテスト（LEAP・試験日課）は日付と名前。
String testKeyOf(UpcomingItem x) {
  final id = x.source?.id;
  if (id != null) return 't_$id';
  final d = x.date;
  final safe = x.title.replaceAll('/', '／').replaceAll(RegExp(r'\s+'), '_');
  return 'g_${d.year}-${_two(d.month)}-${_two(d.day)}_$safe';
}
