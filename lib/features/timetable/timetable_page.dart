import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/date_format.dart';
import 'schedule_config_page.dart';
import 'school_periods.dart';
import 'school_settings_page.dart';
import 'subject_color_page.dart';
import 'subject_colors.dart';
import 'subject_manage_page.dart';
import 'timetable_models.dart';
import 'timetable_repository.dart';
import 'timetable_version.dart';
import 'timetable_version_repository.dart';
import 'week_cycle.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late final TimetableRepository _repository;
  late final TimetableVersionRepository _versionRepository;
  late final Stream<TimetableData> _stream;

  bool _isSeeding = false;
  String? _errorMessage;

  /// 選んでいる版の切り替え日（null＝最初の時間割）
  DateTime? _selectedFrom;
  bool _hasPicked = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _repository = TimetableRepository(uid: uid);
    _versionRepository = TimetableVersionRepository(uid: uid);
    _stream = _repository.watch();
  }

  Future<void> _seed() async {
    setState(() {
      _isSeeding = true;
      _errorMessage = null;
    });
    try {
      await _repository.seedInitialData();
    } catch (e) {
      setState(() => _errorMessage = '登録に失敗しました：$e');
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  TimetableVersion? _findVersion(TimetableData data, DateTime? from) {
    if (from == null) return null;
    for (final v in data.versions) {
      if (dateKey(v.validFrom) == dateKey(from)) return v;
    }
    return null;
  }

  Future<void> _createVersion(List<TimetableSlot> copyFrom) async {
    final date = await showDatePicker(
      context: context,
      helpText: '新しい時間割を使い始める日',
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (date == null) return;
    await _versionRepository.createVersion(date, copyFrom);
    setState(() {
      _selectedFrom = date;
      _hasPicked = true;
    });
  }

  Future<void> _deleteVersion(TimetableVersion v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${formatDateJa(v.validFrom)}からの時間割を削除しますか？'),
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
    if (ok != true) return;
    await _versionRepository.deleteVersion(v.validFrom);
    setState(() {
      _selectedFrom = null;
      _hasPicked = true;
    });
  }

  Future<void> _editCell(
    TimetableData data,
    TimetableVersion? version,
    WeekType weekType,
    int weekday,
    int period,
  ) async {
    // 戻り値：科目名／''＝空き／null＝キャンセル
    final picked = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(
          '${data.config.useWeekCycle ? '${weekType.label} ' : ''}'
          '${weekdayLabel(weekday)}曜 $period限',
        ),
        children: [
          for (final s in data.subjects)
            SimpleDialogOption(
              onPressed: () => Navigator.of(c).pop(s.name),
              child: Text(s.name),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(c).pop(''),
            child: const Text('（空き）'),
          ),
        ],
      ),
    );
    if (picked == null) return;
    await _versionRepository.setSlot(
      version: version,
      weekType: weekType,
      weekday: weekday,
      period: period,
      subject: picked.isEmpty ? null : picked,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TimetableData>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _SimpleScaffold(child: Text('読み込みに失敗しました\n${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const _SimpleScaffold(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;

        if (!data.isSeeded) {
          return _SimpleScaffold(
            child: FilledButton.icon(
              onPressed: _isSeeding ? null : _seed,
              icon: const Icon(Icons.download),
              label: const Text('基本時間割を登録する'),
            ),
          );
        }

        // 最初は「今日使われている版」を表示
        if (!_hasPicked) {
          TimetableVersion? current;
          final today = DateTime.now();
          for (final v in data.versions) {
            if (!v.validFrom.isAfter(today)) current = v;
          }
          _selectedFrom = current?.validFrom;
        }
        final version = _findVersion(data, _selectedFrom);
        final slots = version?.slots ?? data.slots;

        // Ⅰ・Ⅱ週を使わない設定なら、時間割は1つだけ
        final weeks = data.config.useWeekCycle
            ? const [WeekType.one, WeekType.two]
            : const [WeekType.one];

        return DefaultTabController(
          length: weeks.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('時間割'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.menu_book_outlined),
                  tooltip: '科目の管理',
                  onPressed: () => _push(const SubjectManagePage()),
                ),
                IconButton(
                  icon: const Icon(Icons.schedule),
                  tooltip: '時程の設定（時限の時刻・コマ数・Ⅰ・Ⅱ週）',
                  onPressed: () => _push(const ScheduleConfigPage()),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: '学校の設定',
                  onPressed: () => _push(const SchoolSettingsPage()),
                ),
                IconButton(
                  icon: const Icon(Icons.palette_outlined),
                  tooltip: '教科の色',
                  onPressed: () => _push(const SubjectColorPage()),
                ),
                const SizedBox(width: 8),
              ],
              bottom: weeks.length < 2
                  ? null
                  : const TabBar(
                      tabs: [
                        Tab(text: 'Ⅰ週'),
                        Tab(text: 'Ⅱ週'),
                      ],
                    ),
            ),
            body: Column(
              children: [
                if (data.hasInitialDataUpdate)
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: ListTile(
                      title: const Text('追加の初期データがあります'),
                      subtitle: Text(_errorMessage ?? '学校休業日・短縮日課・試験日課'),
                      trailing: FilledButton(
                        onPressed: _isSeeding ? null : _seed,
                        child: const Text('登録'),
                      ),
                    ),
                  ),

                // 版の選択・新しい時間割・削除
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: version == null
                              ? ''
                              : dateKey(version.validFrom),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('最初の時間割'),
                            ),
                            for (final v in data.versions)
                              DropdownMenuItem(
                                value: dateKey(v.validFrom),
                                child: Text('${formatDateJa(v.validFrom)}から'),
                              ),
                          ],
                          onChanged: (key) => setState(() {
                            _hasPicked = true;
                            _selectedFrom = (key == null || key.isEmpty)
                                ? null
                                : data.versions
                                      .firstWhere(
                                        (v) => dateKey(v.validFrom) == key,
                                      )
                                      .validFrom;
                          }),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'この時間割をコピーして新しい時間割を作る',
                        onPressed: () => _createVersion(slots),
                      ),
                      if (version != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'この時間割を削除',
                          onPressed: () => _deleteVersion(version),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      for (final w in weeks)
                        _WeekTable(
                          data: data,
                          slots: slots,
                          weekType: w,
                          onTapCell: (weekday, period) =>
                              _editCell(data, version, w, weekday, period),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SimpleScaffold extends StatelessWidget {
  const _SimpleScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('時間割')),
    body: Center(
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}

/// 1週間分の時間割表（マスをタップで編集）
class _WeekTable extends StatelessWidget {
  const _WeekTable({
    required this.data,
    required this.slots,
    required this.weekType,
    required this.onTapCell,
  });

  final TimetableData data;
  final List<TimetableSlot> slots;
  final WeekType weekType;
  final void Function(int weekday, int period) onTapCell;

  static const List<String> _wd = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;

    // 授業がある曜日（月〜土。設定で決まる）
    final days = [
      for (var w = DateTime.monday; w <= DateTime.saturday; w++)
        if (SchoolPeriods.periodCountFor(w) > 0) w,
    ];

    Widget cell(Widget child, {Color? color, VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Container(
        color: color,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        alignment: Alignment.center,
        child: child,
      ),
    );

    Widget slotCell(int weekday, int period) {
      if (!SchoolPeriods.isRegularPeriod(weekday, period)) {
        return cell(
          Text('—', style: small?.copyWith(color: cs.outline)),
          color: cs.surfaceContainerLow,
        );
      }
      TimetableSlot? slot;
      for (final s in slots) {
        if (s.weekType == weekType &&
            s.weekday == weekday &&
            s.period == period) {
          slot = s;
        }
      }
      final tap = () => onTapCell(weekday, period);
      if (slot == null) return cell(const SizedBox.shrink(), onTap: tap);

      String? category;
      for (final s in data.subjects) {
        if (s.name == slot.subject) category = s.category;
      }
      final color = subjectColorOf(context, category);
      return cell(
        Text(
          slot.subject,
          textAlign: TextAlign.center,
          style: small?.copyWith(
            color: Color.lerp(color, Colors.black, 0.45),
            fontWeight: FontWeight.bold,
          ),
        ),
        color: color.withValues(alpha: 0.18),
        onTap: tap,
      );
    }

    TableRow row(SchoolPeriod p) => TableRow(
      children: [
        cell(
          Column(
            children: [
              Text(p.label, style: small),
              Text(
                p.start.toString(),
                style: small?.copyWith(color: cs.outline),
              ),
            ],
          ),
        ),
        for (final w in days) slotCell(w, p.number),
      ],
    );

    final lunchAfter = SchoolPeriods.lunchAfterPeriod;
    final hasLunch = lunchAfter > 0 && lunchAfter < SchoolPeriods.all.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Table(
            border: TableBorder.all(color: cs.outlineVariant),
            columnWidths: const {0: FixedColumnWidth(52)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: cs.surfaceContainerHighest),
                children: [
                  cell(const SizedBox.shrink()),
                  for (final w in days) cell(Text(_wd[w - 1])),
                ],
              ),
              for (final p in SchoolPeriods.all.take(
                hasLunch ? lunchAfter : SchoolPeriods.all.length,
              ))
                row(p),
              if (hasLunch) ...[
                TableRow(
                  decoration: BoxDecoration(color: cs.surfaceContainerLow),
                  children: [
                    cell(Text('昼', style: small)),
                    for (final _ in days) cell(const SizedBox.shrink()),
                  ],
                ),
                for (final p in SchoolPeriods.all.skip(lunchAfter)) row(p),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
