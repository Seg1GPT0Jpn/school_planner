import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:school_planner/features/quest_link/quest_link.dart';
import 'package:school_planner/features/quest_link/quest_link_card.dart';
import 'package:school_planner/features/school_tests/upcoming_tests.dart';

void main() {
  test('クエストへ渡すテスト予定：日付順・日付は 2026-10-19 の形', () {
    final items = questUpcomingItems([
      UpcomingItem(
        date: DateTime(2026, 10, 22),
        title: '数学Ⅰ 小テスト',
        kindLabel: '小テスト',
        isTest: true,
        subject: '数学Ⅰ',
      ),
      UpcomingItem(
        date: DateTime(2026, 10, 19),
        title: 'ECⅠ LEAP単語テスト',
        kindLabel: '小テスト',
        isTest: true,
        detail: '1201〜1300',
        period: 2,
        subject: 'ECⅠ',
      ),
    ]);
    expect(items.map((i) => i['date']), ['2026-10-19', '2026-10-22']);
    expect(items.first['detail'], '1201〜1300');
    expect(items.first['period'], 2);
    expect(items.first['subject'], 'ECⅠ');
  });

  test('クエストの成果を読む（こわれた値は 0・なければ null）', () {
    expect(QuestResults.fromMap(null), isNull);
    final at = DateTime(2026, 10, 18, 20);
    final r = QuestResults.fromMap({
      'today': {'minutes': 35, 'answered': 40, 'correct': 30},
      'week': {'minutes': 120, 'answered': 150, 'correct': 120},
      'weak': [
        {'unit': '数学 ＞ 2次関数', 'accuracy': 40},
        {'accuracy': 10},
      ],
      'updatedAt': Timestamp.fromDate(at),
    })!;
    expect(r.today.accuracy, 75);
    expect(r.week.minutes, 120);
    expect(r.weak.single.unit, '数学 ＞ 2次関数');
    expect(r.todayAt(DateTime(2026, 10, 18, 23)).minutes, 35);
    expect(r.todayAt(DateTime(2026, 10, 19, 7)).minutes, 0, reason: '日が変わった');
    expect(QuestSum.fromMap('x').answered, 0);
  });

  testWidgets('ホームのカード：成果と苦手な単元、つないでいなければ案内', (t) async {
    final r = QuestResults.fromMap({
      'today': {'minutes': 35, 'answered': 40, 'correct': 30},
      'week': {'minutes': 120, 'answered': 150, 'correct': 120},
      'weak': [
        {'unit': '数学 ＞ 2次関数', 'accuracy': 40},
      ],
    });
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestLinkCard(results: r, now: DateTime(2026, 10, 18)),
        ),
      ),
    );
    expect(find.text('今日：35分・40問（正答率75%）'), findsOneWidget);
    expect(find.text('この1週間：2時間・150問（正答率80%）'), findsOneWidget);
    expect(find.text('・数学 ＞ 2次関数（正答率40%）'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-quest')), findsOneWidget);

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestLinkCard(results: null, now: DateTime(2026, 10, 18)),
        ),
      ),
    );
    expect(find.textContaining('「つづりと連携」すると'), findsOneWidget);
  });
}
