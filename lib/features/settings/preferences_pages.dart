/// 設定の中身の画面（表示・言語と地域・予定・通知・オフライン）
library;

import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
import 'settings_scope.dart';

/// 選ぶだけの小さな画面を出す
Future<T?> pickOne<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T current,
  required String Function(T) label,
  String Function(T)? note,
}) => showDialog<T>(
  context: context,
  builder: (c) => SimpleDialog(
    title: Text(title),
    children: [
      for (final o in options)
        ListTile(
          title: Text(label(o)),
          subtitle: note == null ? null : Text(note(o)),
          trailing: o == current ? const Icon(Icons.check) : null,
          onTap: () => Navigator.pop(c, o),
        ),
    ],
  ),
);

/// 設定を1つ変えて保存する
Future<void> saveSettings(BuildContext context, AppSettings next) async {
  final repository = SettingsScope.repositoryOf(context);
  if (repository == null) return;
  await repository.save(next);
}

/// 設定の画面の入れもの（見た目をそろえる）
class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: children,
        ),
      ),
    ),
  );
}

/// 説明だけの行
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.outline,
        fontSize: 12,
      ),
    ),
  );
}

// ───────────────────────────── 表示 ─────────────────────────────

class ViewSettingsPage extends StatelessWidget {
  const ViewSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return _SettingsScaffold(
      title: '表示',
      children: [
        ListTile(
          leading: const Icon(Icons.today_outlined),
          title: const Text('週の始まり'),
          subtitle: Text(s.weekStart.label),
          onTap: () async {
            final v = await pickOne<WeekStart>(
              context,
              title: '週の始まり',
              options: WeekStart.values,
              current: s.weekStart,
              label: (x) => x.label,
            );
            if (v != null && context.mounted) {
              await saveSettings(context, s.copyWith(weekStart: v));
            }
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.weekend_outlined),
          title: const Text('週末を表示する'),
          subtitle: const Text('OFF にすると、週・月ビューで土日を隠します'),
          value: s.showWeekend,
          onChanged: (v) => saveSettings(context, s.copyWith(showWeekend: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.history_toggle_off),
          title: const Text('過ぎた予定をうすくする'),
          value: s.dimPastEvents,
          onChanged: (v) => saveSettings(context, s.copyWith(dimPastEvents: v)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.unfold_more),
          title: const Text('短い予定も読めるようにする'),
          subtitle: const Text('15分などの短い予定でも、名前が隠れない高さにします'),
          value: s.boostShortEvents,
          onChanged: (v) =>
              saveSettings(context, s.copyWith(boostShortEvents: v)),
        ),
        ListTile(
          leading: const Icon(Icons.view_column_outlined),
          title: const Text('カスタムビュー'),
          subtitle: Text(s.customView.label),
          onTap: () async {
            final v = await pickOne<CustomViewRange>(
              context,
              title: 'カスタムビュー',
              options: CustomViewRange.values,
              current: s.customView,
              label: (x) => x.label,
            );
            if (v != null && context.mounted) {
              await saveSettings(context, s.copyWith(customView: v));
            }
          },
        ),
        const _Note('カスタムビューは、カレンダーの表示の切りかえに追加されます。'),
      ],
    );
  }
}

// ────────────────────────── 言語と地域 ──────────────────────────

class RegionSettingsPage extends StatelessWidget {
  const RegionSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final now = DateTime.now();
    return _SettingsScaffold(
      title: '言語と地域',
      children: [
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('言語'),
          subtitle: const Text('日本語'),
          enabled: false,
        ),
        ListTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title: const Text('日付の形式'),
          subtitle: Text(s.date(now, weekday: true)),
          onTap: () async {
            final v = await pickOne<DateStyle>(
              context,
              title: '日付の形式',
              options: DateStyle.values,
              current: s.dateStyle,
              label: (x) => formatDateWith(now, x),
              note: (x) => '例：${x.sample}',
            );
            if (v != null && context.mounted) {
              await saveSettings(context, s.copyWith(dateStyle: v));
            }
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.schedule),
          title: const Text('24時間表示'),
          subtitle: Text(
            '${formatMinutesWith(13 * 60 + 30, use24Hour: s.use24Hour)} のように出します',
          ),
          value: s.use24Hour,
          onChanged: (v) => saveSettings(context, s.copyWith(use24Hour: v)),
        ),
      ],
    );
  }
}

// ───────────────────────────── 予定 ─────────────────────────────

class EventSettingsPage extends StatelessWidget {
  const EventSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return _SettingsScaffold(
      title: '予定',
      children: [
        ListTile(
          leading: const Icon(Icons.timelapse),
          title: const Text('予定のデフォルトの長さ'),
          subtitle: Text('${s.defaultEventMinutes}分'),
          onTap: () async {
            final v = await pickOne<int>(
              context,
              title: '予定のデフォルトの長さ',
              options: durationChoices,
              current: s.defaultEventMinutes,
              label: (x) => '$x分',
            );
            if (v != null && context.mounted) {
              await saveSettings(context, s.copyWith(defaultEventMinutes: v));
            }
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.fast_forward_outlined),
          title: const Text('少し早く終わらせる'),
          subtitle: Text(
            '次の予定までの余裕を作ります'
            '（${s.defaultEventMinutes}分 → '
            '${s.copyWith(speedyEvents: true).eventMinutes}分）',
          ),
          value: s.speedyEvents,
          onChanged: (v) => saveSettings(context, s.copyWith(speedyEvents: v)),
        ),
        const _Note('新しく予定を作るときの、はじめの長さです。あとから自由に変えられます。'),
      ],
    );
  }
}

// ───────────────────────────── 通知 ─────────────────────────────

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return _SettingsScaffold(
      title: '通知',
      children: [
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('予定の通知'),
          subtitle: Text(reminderLabel(s.defaultReminderMinutes)),
          onTap: () async {
            final v = await pickOne<int>(
              context,
              title: '予定の通知',
              options: reminderChoices,
              current: s.defaultReminderMinutes,
              label: reminderLabel,
            );
            if (v != null && context.mounted) {
              await saveSettings(
                context,
                s.copyWith(defaultReminderMinutes: v),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.wb_sunny_outlined),
          title: const Text('終日の予定を知らせる時刻'),
          subtitle: Text(s.time(s.allDayReminderMinutes)),
          onTap: () async {
            final v = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: s.allDayReminderMinutes ~/ 60,
                minute: s.allDayReminderMinutes % 60,
              ),
            );
            if (v != null && context.mounted) {
              await saveSettings(
                context,
                s.copyWith(allDayReminderMinutes: v.hour * 60 + v.minute),
              );
            }
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_outlined),
          title: const Text('通知音を鳴らす'),
          subtitle: const Text('OFF にすると、音を出さずに通知します'),
          value: s.notificationSound,
          onChanged: (v) =>
              saveSettings(context, s.copyWith(notificationSound: v)),
        ),
        const _Note('通知は Android のアプリだけで動きます。'),
      ],
    );
  }
}

// ─────────────────────────── オフライン ───────────────────────────

class OfflineSettingsPage extends StatelessWidget {
  const OfflineSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return _SettingsScaffold(
      title: 'オフライン',
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.cloud_off_outlined),
          title: const Text('オフラインでも使う'),
          subtitle: const Text('電波がなくても、前に見た予定と時間割を出します'),
          value: s.offlineEnabled,
          onChanged: (v) =>
              saveSettings(context, s.copyWith(offlineEnabled: v)),
        ),
        const _Note(
          'オフラインのときに変えた内容は、電波がもどったときにまとめて保存されます。\n'
          'この設定を変えたときは、つづりを開き直すと切りかわります。',
        ),
      ],
    );
  }
}
