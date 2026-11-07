import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_links.dart';

/// 計画シート（web/sheets/index.html）：記入して印刷できる2つのテンプレート。
/// 書いた内容はそのブラウザに保存される（ログインはいらない）。
enum PlanSheet {
  daily(
    'daily',
    '毎日の目標シート',
    '残り日数・日付・その日のやること目標・予定・達成したこと・毎日の習慣。模試やテストの点数目標の枠も入れられる',
  ),
  nset('nset', '目標達成のための n 個', '「○○に合格するための n 個（n＝〇＋α）」を教科ごとに書き出し、番号でチェックしていく');

  const PlanSheet(this.id, this.title, this.description);
  final String id;
  final String title;
  final String description;
}

/// 計画シートの住所。Web 版は同じサイトの /sheets/、アプリは公開中の Web 版を開く
Uri planSheetUri(PlanSheet sheet, {bool web = kIsWeb, Uri? base}) {
  final origin = web ? (base ?? Uri.base).origin : appWebUrl;
  return Uri.parse('$origin/sheets/?sheet=${sheet.id}');
}

/// 計画シートを選んで開く
Future<void> openPlanSheets(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              '計画シート（記入して印刷できる）',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'ブラウザで開きます。書いた内容はその端末に保存され、A4・B5 で印刷できます。白紙のまま印刷して手で書くこともできます。',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          for (final s in PlanSheet.values)
            ListTile(
              key: ValueKey('plan-sheet-${s.id}'),
              leading: Icon(
                s == PlanSheet.daily
                    ? Icons.event_note_outlined
                    : Icons.checklist_rtl,
              ),
              title: Text(s.title),
              subtitle: Text(s.description),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () {
                Navigator.of(context).pop();
                launchUrl(
                  planSheetUri(s),
                  mode: LaunchMode.externalApplication,
                  webOnlyWindowName: '_blank',
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
