import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:school_planner/features/goals/plan_sheets.dart';

void main() {
  test('計画シートの住所：アプリは公開中の Web 版、Web 版は同じサイトの /sheets/', () {
    expect(
      planSheetUri(PlanSheet.daily, web: false).toString(),
      'https://school-planner-30628.web.app/sheets/?sheet=daily',
    );
    expect(
      planSheetUri(
        PlanSheet.nset,
        web: true,
        base: Uri.parse('http://localhost:5000/#/goals'),
      ).toString(),
      'http://localhost:5000/sheets/?sheet=nset',
    );
  });

  test('計画シートのページが web/ に入っていて、2つのシートと印刷の設定がある', () {
    final html = File('web/sheets/index.html').readAsStringSync();
    for (final s in PlanSheet.values) {
      expect(html, contains("'${s.id}'"), reason: s.id);
    }
    expect(html, contains('@page'));
    expect(html, contains('B5'));
    expect(html, contains('毎日マッピ'));
  });

  testWidgets('計画シートの選びかた：2つのシートが並ぶ', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openPlanSheets(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    for (final s in PlanSheet.values) {
      expect(find.byKey(ValueKey('plan-sheet-${s.id}')), findsOneWidget);
    }
  });
}
