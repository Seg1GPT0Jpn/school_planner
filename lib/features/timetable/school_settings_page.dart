import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import 'school_periods.dart';
import 'school_settings_repository.dart';
import 'timetable_models.dart';
import 'timetable_repository.dart';

/// 学校の設定（休業日・特別な日課）
class SchoolSettingsPage extends StatefulWidget {
  const SchoolSettingsPage({super.key});

  @override
  State<SchoolSettingsPage> createState() => _SchoolSettingsPageState();
}

class _SchoolSettingsPageState extends State<SchoolSettingsPage> {
  late final Stream<TimetableData> _stream;
  late final SchoolSettingsRepository _repository;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _stream = TimetableRepository(uid: uid).watch();
    _repository = SchoolSettingsRepository(uid: uid);
  }

  Future<bool> _confirm(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// 休業日を追加：期間を選ぶ → 名前を入れる
  Future<void> _addClosure() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (range == null || !mounted) return;

    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('休業日の名前'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例：夏休み、臨時休校'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(controller.text.trim()),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty) return;

    await _repository.addClosure(
      SchoolClosure(start: range.start, end: range.end, title: title),
    );
  }

  /// 指定した範囲（両端を含む）のうち、土日を除いた日の一覧を返す
  List<DateTime> _weekdaysInRange(DateTime start, DateTime end) {
    final result = <DateTime>[];
    var d = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(last)) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
        result.add(d);
      }
      d = d.add(const Duration(days: 1));
    }
    return result;
  }

  /// 短縮日課・試験日課・特殊日課の日を追加：
  /// 「1日だけ」か「期間（連続する日）」かを選び、日付を選ぶ → 日課とメモ。
  /// 期間で指定した場合、土日は自動で除かれる（テスト・授業は行われないため）。
  Future<void> _addSchedule() async {
    final isRange = await showDialog<bool>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('日付の指定方法'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('1日だけ指定する'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('期間（連続する日）で指定する'),
          ),
        ],
      ),
    );
    if (isRange == null || !mounted) return;

    List<DateTime> targetDates;
    if (isRange) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035, 12, 31),
      );
      if (range == null || !mounted) return;
      targetDates = _weekdaysInRange(range.start, range.end);
      if (targetDates.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('選んだ期間に平日がありません')));
        return;
      }
    } else {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035, 12, 31),
      );
      if (date == null || !mounted) return;
      targetDates = [date];
    }

    var schedule = DaySchedule.shortened;
    final noteController = TextEditingController();

    // 特殊日課用の入力値
    var customStart =
        SchoolPeriods.all.isNotEmpty
            ? SchoolPeriods.all.first.start
            : const ClockTime(8, 50);
    var customCount = SchoolPeriods.periodCountFor(targetDates.first.weekday);
    if (customCount == 0) customCount = 5;
    final minutesController = TextEditingController(text: '65');
    final breakController = TextEditingController(text: '10');
    final countController = TextEditingController(text: '$customCount');
    var customHasLunch = false;
    final lunchAfterController = TextEditingController(
      text: '${SchoolPeriods.lunchAfterPeriod > 0 ? SchoolPeriods.lunchAfterPeriod : 3}',
    );
    final lunchMinutesController = TextEditingController(
      text:
          '${SchoolPeriods.lunchEnd.totalMinutes - SchoolPeriods.lunchStart.totalMinutes}',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) {
          Future<void> pickStart() async {
            final picked = await showTimePicker(
              context: c,
              initialTime: TimeOfDay(
                hour: customStart.hour,
                minute: customStart.minute,
              ),
            );
            if (picked != null) {
              setDialogState(
                () => customStart = ClockTime(picked.hour, picked.minute),
              );
            }
          }

          return AlertDialog(
            title: Text(
              targetDates.length <= 1
                  ? formatDateJa(targetDates.first)
                  : '${formatDateJa(targetDates.first)} 〜 '
                        '${formatDateJa(targetDates.last)}（平日のみ）',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<DaySchedule>(
                    segments: const [
                      ButtonSegment(
                        value: DaySchedule.shortened,
                        label: Text('短縮日課'),
                      ),
                      ButtonSegment(
                        value: DaySchedule.exam,
                        label: Text('試験日課'),
                      ),
                      ButtonSegment(
                        value: DaySchedule.custom,
                        label: Text('特殊日課'),
                      ),
                    ],
                    selected: {schedule},
                    onSelectionChanged: (s) =>
                        setDialogState(() => schedule = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (schedule == DaySchedule.custom) ...[
                    Text(
                      'この日だけの特別な時程を作ります（例：大掃除で65分授業）。'
                      '1時間目の開始時刻から、指定した長さの授業を休み時間を挟んで並べます。',
                      style: Theme.of(c).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('1時間目の開始時刻'),
                      trailing: Text('$customStart'),
                      onTap: pickStart,
                    ),
                    TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '1コマの長さ（分）'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: breakController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '授業と授業の間の休み時間（分）',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: countController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'コマ数'),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: customHasLunch,
                      onChanged: (v) =>
                          setDialogState(() => customHasLunch = v ?? false),
                      title: const Text('昼休みを入れる'),
                    ),
                    if (customHasLunch) ...[
                      TextField(
                        controller: lunchAfterController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '何時間目のあとに入れるか',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: lunchMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '昼休みの長さ（分）',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: schedule == DaySchedule.custom
                          ? 'メモ（例：大掃除のため）'
                          : 'メモ（例：後期期末試験）',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;

    if (schedule == DaySchedule.custom) {
      final periods = _buildCustomPeriods(
        start: customStart,
        periodMinutes: int.tryParse(minutesController.text) ?? 65,
        breakMinutes: int.tryParse(breakController.text) ?? 10,
        count: int.tryParse(countController.text) ?? customCount,
        hasLunch: customHasLunch,
        lunchAfterPeriod: int.tryParse(lunchAfterController.text) ?? 3,
        lunchMinutes: int.tryParse(lunchMinutesController.text) ?? 45,
      );
      if (periods.isEmpty || !mounted) return;
      for (final d in targetDates) {
        await _repository.setCustomSchedule(d, periods, noteController.text);
      }
    } else {
      for (final d in targetDates) {
        await _repository.setSchedule(d, schedule, noteController.text);
      }
    }
  }

  /// 特殊日課の時限一覧を作る（開始時刻から、休み時間を挟んで順に並べる）
  static List<SchoolPeriod> _buildCustomPeriods({
    required ClockTime start,
    required int periodMinutes,
    required int breakMinutes,
    required int count,
    required bool hasLunch,
    required int lunchAfterPeriod,
    required int lunchMinutes,
  }) {
    if (periodMinutes <= 0 || count <= 0) return const [];
    final periods = <SchoolPeriod>[];
    var cursor = start;
    for (var i = 1; i <= count; i++) {
      final end = cursor.addMinutes(periodMinutes);
      periods.add(SchoolPeriod(number: i, start: cursor, end: end));
      final gap = (hasLunch && i == lunchAfterPeriod)
          ? lunchMinutes
          : breakMinutes;
      cursor = end.addMinutes(gap < 0 ? 0 : gap);
    }
    return periods;
  }

  /// [prev] の次の「学校の日」（土日を飛ばした翌営業日）が [next] かどうか
  static bool _isNextSchoolDay(DateTime prev, DateTime next) {
    var candidate = DateTime(
      prev.year,
      prev.month,
      prev.day,
    ).add(const Duration(days: 1));
    while (candidate.weekday == DateTime.saturday ||
        candidate.weekday == DateTime.sunday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate == DateTime(next.year, next.month, next.day);
  }

  static bool _samePeriods(List<SchoolPeriod>? a, List<SchoolPeriod>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameScheduleKind(DayOverride a, DayOverride b) {
    if (a.schedule != b.schedule) return false;
    if ((a.note ?? '') != (b.note ?? '')) return false;
    if (a.schedule == DaySchedule.custom) {
      return _samePeriods(a.customPeriods, b.customPeriods);
    }
    return true;
  }

  /// 同じ日課・メモが、土日を挟んでも連続する「学校の日」で続いているものを
  /// 1つのまとまりにする（例：定期テストの5日間を1つの表示にする）
  static List<List<DayOverride>> _groupSchedules(List<DayOverride> schedules) {
    final groups = <List<DayOverride>>[];
    for (final o in schedules) {
      if (groups.isNotEmpty) {
        final last = groups.last.last;
        if (_sameScheduleKind(last, o) && _isNextSchoolDay(last.date, o.date)) {
          groups.last.add(o);
          continue;
        }
      }
      groups.add([o]);
    }
    return groups;
  }

  Widget _header(String title, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('追加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学校の設定')),
      body: StreamBuilder<TimetableData>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final closures = [...data.closures]
            ..sort((a, b) => a.start.compareTo(b.start));
          final schedules = [
            for (final o in data.dayOverrides)
              if (o.schedule != null) o,
          ]..sort((a, b) => a.date.compareTo(b.date));
          final scheduleGroups = _groupSchedules(schedules);

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                children: [
                  _header('学校休業日', _addClosure),
                  for (final c in closures)
                    ListTile(
                      title: Text(c.title),
                      subtitle: Text(
                        '${formatDateJa(c.start)} 〜 ${formatDateJa(c.end)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '削除',
                        onPressed: () async {
                          if (await _confirm('「${c.title}」を削除しますか？')) {
                            await _repository.deleteClosure(c);
                          }
                        },
                      ),
                    ),
                  const Divider(),
                  _header('短縮日課・試験日課・特殊日課の日', _addSchedule),
                  for (final group in scheduleGroups)
                    ListTile(
                      title: Text(
                        group.length <= 1
                            ? '${formatDateJa(group.first.date)}　'
                                  '${group.first.schedule!.label}'
                            : '${formatDateJa(group.first.date)} 〜 '
                                  '${formatDateJa(group.last.date)}　'
                                  '${group.first.schedule!.label}',
                      ),
                      subtitle: () {
                        final o = group.first;
                        final parts = [
                          if (o.schedule == DaySchedule.custom &&
                              (o.customPeriods?.isNotEmpty ?? false))
                            '${o.customPeriods!.first.start}〜　'
                                '${o.customPeriods!.length}コマ・'
                                '${o.customPeriods!.first.durationMinutes}分授業',
                          if (o.note != null) o.note!,
                        ];
                        return parts.isEmpty ? null : Text(parts.join('　'));
                      }(),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '通常日課に戻す',
                        onPressed: () async {
                          final title = group.length <= 1
                              ? '通常日課に戻しますか？'
                              : '${group.length}日分（'
                                    '${formatDateJa(group.first.date)}〜'
                                    '${formatDateJa(group.last.date)}）'
                                    'すべて通常日課に戻しますか？';
                          if (await _confirm(title)) {
                            for (final o in group) {
                              await _repository.clearSchedule(o.date);
                            }
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
