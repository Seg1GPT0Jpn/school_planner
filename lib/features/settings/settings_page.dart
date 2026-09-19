import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../belongings/belongings_pages.dart';
import '../events/category_manage_page.dart';
import '../events/event_category_repository.dart';
import '../notifications/notification_planner.dart';
import '../recurring/recurring_pages.dart';
import '../timetable/school_settings_page.dart';
import '../timetable/subject_color_page.dart';
import '../timetable/subject_manage_page.dart';

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
    String t(int h, int m) => '$h:${m.toString().padLeft(2, '0')}';

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
              header('通知（Android のアプリのみ）'),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('お知らせの時刻'),
                subtitle: Text(
                  '前日 ${t(eveningHour, eveningMinute)}・'
                  '当日 ${t(morningHour, morningMinute)}・'
                  '予定の${eventReminder.inMinutes}分前',
                ),
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
