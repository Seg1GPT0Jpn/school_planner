import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'school_periods.dart';
import 'timetable_repository.dart';
import 'week_cycle.dart';

/// 時間割タブ
class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late final TimetableRepository _repository;
  late final Stream<TimetableData> _stream;

  bool _isSeeding = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = TimetableRepository(
      uid: FirebaseAuth.instance.currentUser!.uid,
    );
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

        // まだ初期データを登録していない
        if (!data.isSeeded) {
          return _SimpleScaffold(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('時間割がまだ登録されていません'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSeeding ? null : _seed,
                  icon: const Icon(Icons.download),
                  label: const Text('基本時間割を登録する'),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // Ⅰ週・Ⅱ週の時間割表
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('時間割'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Ⅰ週'),
                  Tab(text: 'Ⅱ週'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _WeekTable(data: data, weekType: WeekType.one),
                _WeekTable(data: data, weekType: WeekType.two),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// タイトルと中央の表示だけの簡単な画面
class _SimpleScaffold extends StatelessWidget {
  const _SimpleScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('時間割')),
      body: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    );
  }
}

/// 1週間分の時間割表（行：時限、列：曜日）
class _WeekTable extends StatelessWidget {
  const _WeekTable({required this.data, required this.weekType});

  final TimetableData data;
  final WeekType weekType;

  static const List<String> _weekdayLabels = ['月', '火', '水', '木', '金'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final smallText = Theme.of(context).textTheme.bodySmall;

    Widget cell(Widget child, {Color? color}) => Container(
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      alignment: Alignment.center,
      child: child,
    );

    TableRow periodRow(SchoolPeriod period) {
      return TableRow(
        children: [
          cell(
            Column(
              children: [
                Text(period.label, style: smallText),
                Text(
                  period.start.toString(),
                  style: smallText?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
          for (var i = 0; i < 5; i++)
            _slotCell(
              context,
              weekday: DateTime.monday + i,
              period: period.number,
              cellBuilder: cell,
            ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Table(
            border: TableBorder.all(color: colorScheme.outlineVariant),
            columnWidths: const {0: FixedColumnWidth(52)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // 見出し（曜日）
              TableRow(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                ),
                children: [
                  cell(const SizedBox.shrink()),
                  for (final label in _weekdayLabels) cell(Text(label)),
                ],
              ),
              // 1〜3限
              for (final period in SchoolPeriods.all.take(
                SchoolPeriods.lunchAfterPeriod,
              ))
                periodRow(period),
              // 昼休み
              TableRow(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                ),
                children: [
                  cell(Text('昼', style: smallText)),
                  for (var i = 0; i < 5; i++) cell(const SizedBox.shrink()),
                ],
              ),
              // 4・5限
              for (final period in SchoolPeriods.all.skip(
                SchoolPeriods.lunchAfterPeriod,
              ))
                periodRow(period),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotCell(
    BuildContext context, {
    required int weekday,
    required int period,
    required Widget Function(Widget child, {Color? color}) cellBuilder,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final smallText = Theme.of(context).textTheme.bodySmall;

    // 水・金の5限など、通常は存在しない時限
    if (!SchoolPeriods.isRegularPeriod(weekday, period)) {
      return cellBuilder(
        Text('—', style: smallText?.copyWith(color: colorScheme.outline)),
        color: colorScheme.surfaceContainerLow,
      );
    }

    final slot = data.slotAt(weekType, weekday, period);
    return cellBuilder(
      Text(slot?.subject ?? '', style: smallText, textAlign: TextAlign.center),
    );
  }
}
