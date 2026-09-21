import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../belongings/belongings_pages.dart';
import '../events/category_manage_page.dart';
import '../events/event_category_repository.dart';
import '../google_calendar/google_calendar_page.dart';
import '../recurring/recurring_pages.dart';
import '../school_tests/weekly_rules_page.dart';
import '../timetable/school_settings_page.dart';
import '../timetable/subject_color_page.dart';
import '../timetable/subject_manage_page.dart';
import 'app_settings.dart';
import 'preferences_pages.dart';
import 'settings_scope.dart';
import 'shortcuts_page.dart';
import 'timezone_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final s = SettingsScope.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            children: [
              header('全般'),
              ListTile(
                leading: const Icon(Icons.calendar_view_month_outlined),
                title: const Text('表示'),
                subtitle: Text(
                  '${s.weekStart.label}はじまり・'
                  '${s.showWeekend ? '週末あり' : '週末なし'}',
                ),
                onTap: () => _push(context, const ViewSettingsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('言語と地域'),
                subtitle: Text(
                  '${s.date(DateTime.now())}・'
                  '${s.use24Hour ? '24時間表示' : '午前・午後'}',
                ),
                onTap: () => _push(context, const RegionSettingsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.timelapse),
                title: const Text('予定'),
                subtitle: Text('デフォルトの長さ ${s.defaultEventMinutes}分'),
                onTap: () => _push(context, const EventSettingsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('通知'),
                subtitle: Text(
                  '${reminderLabel(s.defaultReminderMinutes)}・'
                  '終日は ${s.time(s.allDayReminderMinutes)}',
                ),
                onTap: () => _push(context, const NotificationSettingsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('タイムゾーンと世界時計'),
                subtitle: Text(
                  s.showWorldClock && s.secondTimeZone.isNotEmpty
                      ? '${s.timeZone}・${s.secondTimeZone}'
                      : s.timeZone,
                ),
                onTap: () => _push(context, const TimeZoneSettingsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.keyboard_outlined),
                title: const Text('キーボードショートカット'),
                subtitle: Text(s.keyboardShortcuts ? '使う' : '使わない'),
                onTap: () => _push(context, const ShortcutsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('オフライン'),
                subtitle: Text(s.offlineEnabled ? 'オフラインでも使う' : '使わない'),
                onTap: () => _push(context, const OfflineSettingsPage()),
              ),
              header('学校'),
              ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('学校の設定'),
                subtitle: const Text('休業日・短縮日課・試験日課'),
                onTap: () => _push(context, const SchoolSettingsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('科目の管理'),
                onTap: () => _push(context, const SubjectManagePage()),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('教科の色'),
                onTap: () => _push(context, const SubjectColorPage()),
              ),
              ListTile(
                leading: const Icon(Icons.backpack_outlined),
                title: const Text('持ち物'),
                onTap: () => _push(context, const BelongingsSettingsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.spellcheck),
                title: const Text('毎週の単語テスト'),
                subtitle: const Text('LEAP などの範囲・最後の番号'),
                onTap: () => _push(context, const WeeklyRulesPage()),
              ),
              header('予定'),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: const Text('予定のカテゴリ'),
                onTap: () => _push(
                  context,
                  CategoryManagePage(
                    repository: EventCategoryRepository(uid: uid),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('塾・部活などの定期の予定'),
                onTap: () => openRecurringList(context),
              ),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Google カレンダー'),
                subtitle: const Text('読み込み・書き込みの設定'),
                onTap: () => _push(context, const GoogleCalendarPage()),
              ),
              header('アカウント'),
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(email),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('ログアウト'),
                onTap: () => _signOut(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
