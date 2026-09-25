/// ④〜⑧：学校の時程（週タイプ・曜日ごとのコマ数・通常日課・昼休み・短縮日課）を
/// 順番に、かんたんな入力で作っていくウィザード
///
/// あとから「設定 ＞ 時程の設定」で、1こまずつ細かく直すこともできる。
library;

import 'package:material_ui/material_ui.dart';

import '../timetable/school_periods.dart';
import '../timetable/schedule_config_page.dart' show generatePeriods;

const _wd = ['月', '火', '水', '木', '金', '土', '日'];

class OnboardingScheduleFlow extends StatefulWidget {
  const OnboardingScheduleFlow({super.key, required this.onDone});

  /// できあがった時程の設定を渡す
  final ValueChanged<ScheduleConfig> onDone;

  @override
  State<OnboardingScheduleFlow> createState() =>
      _OnboardingScheduleFlowState();
}

class _OnboardingScheduleFlowState extends State<OnboardingScheduleFlow> {
  final _pageController = PageController();
  int _step = 0;
  static const _stepCount = 5;

  // ④ 週タイプ
  bool _useWeekCycle = true;

  // ⑤ 曜日ごとのコマ数
  Map<int, int> _periodCounts = {...ScheduleConfig.standard.periodCounts};

  // ⑥ 通常日課
  ClockTime _firstStart = const ClockTime(8, 50);
  int _lessonMinutes = 50;
  int _breakMinutes = 10;
  List<SchoolPeriod> _periods = const [];

  // ⑦ 昼休み
  int _lunchAfterPeriod = 0;
  int _lunchMinutes = 45;
  ClockTime? _lunchStart;
  ClockTime? _lunchEnd;

  // ⑧ 短縮日課
  final Map<int, List<SchoolPeriod>> _shortened = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<int> get _distinctCounts => ({
    for (final w in _periodCounts.keys)
      if ((_periodCounts[w] ?? 0) > 0)
        (_periodCounts[w]!).clamp(0, _periods.length),
  }..removeWhere((n) => n == 0)).toList()
    ..sort();

  void _regeneratePeriods() {
    final withLunch = _lunchAfterPeriod > 0;
    final list = generatePeriods(
      firstStart: _firstStart,
      count: _periods.isEmpty ? 5 : _periods.length,
      lessonMinutes: _lessonMinutes,
      breakMinutes: _breakMinutes,
      lunchAfter: withLunch ? _lunchAfterPeriod : 0,
      lunchMinutes: withLunch ? _lunchMinutes : 0,
    );
    setState(() {
      _periods = list;
      if (withLunch && _lunchAfterPeriod < list.length) {
        _lunchStart = list[_lunchAfterPeriod - 1].end;
        _lunchEnd = list[_lunchAfterPeriod].start.addMinutes(-5);
      }
    });
  }

  void _next() {
    if (_step == _stepCount - 1) {
      final config = ScheduleConfig.standard.copyWith(
        useWeekCycle: _useWeekCycle,
        periodCounts: _periodCounts,
        periods: _periods,
        lunchAfterPeriod: _lunchAfterPeriod,
        lunchStart: _lunchStart,
        lunchEnd: _lunchEnd,
        shortened: _shortened,
      );
      widget.onDone(config);
      return;
    }
    setState(() => _step++);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    // 通常日課の初期値を、最初から用意しておく（⑥に来たときに空にならないように）
    _periods = generatePeriods(
      firstStart: _firstStart,
      count: 5,
      lessonMinutes: _lessonMinutes,
      breakMinutes: _breakMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: _step == 0
            ? null
            : IconButton(
                onPressed: _back,
                icon: const Icon(Icons.arrow_back),
              ),
        title: Text('学校の時程を設定（${_step + 1}/$_stepCount）'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / _stepCount,
            backgroundColor: cs.surfaceContainerHighest,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _weekCycleStep(),
                _periodCountStep(),
                _normalPeriodsStep(),
                _lunchStep(),
                _shortenedStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepScaffold({
    required String title,
    String? note,
    required Widget child,
    VoidCallback? onNext,
    String nextLabel = '次へ',
  }) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text(title, style: tt.headlineSmall),
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(note, style: tt.bodyMedium?.copyWith(color: cs.outline)),
            ],
            const SizedBox(height: 20),
            child,
            const SizedBox(height: 28),
            FilledButton(
              onPressed: onNext ?? _next,
              child: Text(nextLabel),
            ),
          ],
        ),
      ),
    );
  }

  // ④ 週タイプ
  Widget _weekCycleStep() => _stepScaffold(
    title: '④ 週の時間割を Ⅰ・Ⅱ週で分けますか？',
    note: '2週間で1回りの時間割を使っている学校なら「分ける」を選んでください。',
    child: Card(
      child: RadioGroup<bool>(
        groupValue: _useWeekCycle,
        onChanged: (v) => setState(() => _useWeekCycle = v ?? _useWeekCycle),
        child: const Column(
          children: [
            RadioListTile<bool>(
              value: true,
              title: Text('分ける（Ⅰ週・Ⅱ週がある）'),
            ),
            RadioListTile<bool>(
              value: false,
              title: Text('分けない（毎週同じ時間割）'),
            ),
          ],
        ),
      ),
    ),
  );

  // ⑤ 曜日ごとのコマ数
  Widget _periodCountStep() => _stepScaffold(
    title: '⑤ 曜日ごとのコマ数を設定してください',
    note: '0 にすると、その曜日は授業なしになります。あとで直せます。',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var w = 1; w <= 7; w++)
              SizedBox(
                width: 90,
                child: Row(
                  children: [
                    Text(_wd[w - 1]),
                    const SizedBox(width: 6),
                    DropdownButton<int>(
                      value: (_periodCounts[w] ?? 0).clamp(0, 8),
                      items: [
                        for (var n = 0; n <= 8; n++)
                          DropdownMenuItem(value: n, child: Text('$n')),
                      ],
                      onChanged: (n) {
                        if (n == null) return;
                        setState(
                          () => _periodCounts = {..._periodCounts, w: n},
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  // ⑥ 通常日課
  Widget _normalPeriodsStep() => _stepScaffold(
    title: '⑥ 通常日課の時限と時間を入力してください',
    note: '1限の始まり・時限の数・授業の長さ・休み時間から、まとめて作ります。',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('1限の始まり'),
                  trailing: Text('$_firstStart'),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: _firstStart.hour,
                        minute: _firstStart.minute,
                      ),
                    );
                    if (t != null) {
                      setState(
                        () => _firstStart = ClockTime(t.hour, t.minute),
                      );
                      _regeneratePeriods();
                    }
                  },
                ),
                _NumberField(
                  label: '時限の数',
                  value: _periods.length,
                  min: 1,
                  max: 8,
                  onChanged: (n) {
                    setState(
                      () => _periods = generatePeriods(
                        firstStart: _firstStart,
                        count: n,
                        lessonMinutes: _lessonMinutes,
                        breakMinutes: _breakMinutes,
                      ),
                    );
                  },
                ),
                _NumberField(
                  label: '授業の長さ（分）',
                  value: _lessonMinutes,
                  min: 5,
                  max: 120,
                  onChanged: (n) {
                    setState(() => _lessonMinutes = n);
                    _regeneratePeriods();
                  },
                ),
                _NumberField(
                  label: '休み時間（分）',
                  value: _breakMinutes,
                  min: 0,
                  max: 60,
                  onChanged: (n) {
                    setState(() => _breakMinutes = n);
                    _regeneratePeriods();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (final p in _periods)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 13,
                    child: Text('${p.number}'),
                  ),
                  title: Text('${p.start} 〜 ${p.end}'),
                  trailing: Text('${p.durationMinutes}分'),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  // ⑦ 昼休み
  Widget _lunchStep() {
    final maxAfter = _periods.length - 1;
    return _stepScaffold(
      title: '⑦ 昼休みを設定してください',
      note: 'なしにする場合は「なし」のままで次へ進めます。',
      child: Card(
        child: Column(
          children: [
            ListTile(
              title: const Text('何限のあと'),
              trailing: DropdownButton<int>(
                value: _lunchAfterPeriod.clamp(0, maxAfter < 0 ? 0 : maxAfter),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('なし')),
                  for (var n = 1; n <= maxAfter; n++)
                    DropdownMenuItem(value: n, child: Text('$n限のあと')),
                ],
                onChanged: (n) {
                  if (n == null) return;
                  setState(() => _lunchAfterPeriod = n);
                  if (n == 0) {
                    setState(() {
                      _lunchStart = null;
                      _lunchEnd = null;
                    });
                    _regeneratePeriods();
                  } else {
                    _regeneratePeriods();
                  }
                },
              ),
            ),
            if (_lunchAfterPeriod > 0)
              _NumberField(
                label: '昼休みの長さ（分）',
                value: _lunchMinutes,
                min: 15,
                max: 90,
                onChanged: (n) {
                  setState(() => _lunchMinutes = n);
                  _regeneratePeriods();
                },
              ),
            if (_lunchAfterPeriod > 0 && _lunchStart != null)
              ListTile(
                title: const Text('昼休みの時間'),
                trailing: Text('$_lunchStart 〜 $_lunchEnd'),
              ),
          ],
        ),
      ),
    );
  }

  // ⑧ 短縮日課
  Widget _shortenedStep() {
    final counts = _distinctCounts;
    return _stepScaffold(
      title: '⑧ 短縮日課の時限と時間を入力してください',
      note: '作らなかったコマ数は、通常日課の前半を使います。あとで設定から直せます。',
      onNext: () => _next(),
      nextLabel: '完了',
      child: Column(
        children: [
          if (counts.isEmpty)
            const Text('曜日ごとのコマ数から、作る必要のある短縮日課はありませんでした。'),
          for (final n in counts) ...[
            _ShortenedGenerator(
              count: n,
              initial: _shortened[n],
              onGenerated: (list) =>
                  setState(() => _shortened[n] = list),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// 数を増減させるだけのシンプルな入力
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 32,
          child: Text('$value', textAlign: TextAlign.center),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
  );
}

/// ⑧ の、コマ数ごとの短縮日課を「まとめて作る」小さなカード
class _ShortenedGenerator extends StatefulWidget {
  const _ShortenedGenerator({
    required this.count,
    required this.initial,
    required this.onGenerated,
  });

  final int count;
  final List<SchoolPeriod>? initial;
  final ValueChanged<List<SchoolPeriod>> onGenerated;

  @override
  State<_ShortenedGenerator> createState() => _ShortenedGeneratorState();
}

class _ShortenedGeneratorState extends State<_ShortenedGenerator> {
  ClockTime _start = const ClockTime(8, 50);
  int _lesson = 40;
  int _break = 10;
  List<SchoolPeriod>? _list;

  @override
  void initState() {
    super.initState();
    _list = widget.initial;
  }

  void _generate() {
    final list = generatePeriods(
      firstStart: _start,
      count: widget.count,
      lessonMinutes: _lesson,
      breakMinutes: _break,
    );
    setState(() => _list = list);
    widget.onGenerated(list);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ふだん${widget.count}コマの日の短縮日課', style: tt.labelLarge),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('1限の始まり'),
              trailing: Text('$_start'),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: _start.hour,
                    minute: _start.minute,
                  ),
                );
                if (t != null) {
                  setState(() => _start = ClockTime(t.hour, t.minute));
                }
              },
            ),
            _NumberField(
              label: '授業の長さ（分）',
              value: _lesson,
              min: 5,
              max: 90,
              onChanged: (n) => setState(() => _lesson = n),
            ),
            _NumberField(
              label: '休み時間（分）',
              value: _break,
              min: 0,
              max: 60,
              onChanged: (n) => setState(() => _break = n),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('作る'),
              ),
            ),
            if (_list != null)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final p in _list!)
                    Chip(label: Text('${p.number}限 ${p.start}〜${p.end}')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
