/// 年間予定 ― 1年分をひと目で見渡すミニカレンダー
library;

import 'package:material_ui/material_ui.dart';

import '../events/calendar_event.dart';
import '../events/event_category.dart';
import '../events/event_category_repository.dart';
import '../events/event_edit_page.dart';
import '../events/event_repository.dart';
import '../review/review_widgets.dart';

const _wd = ['月', '火', '水', '木', '金', '土', '日'];
const _monthNames = [
  '1月', '2月', '3月', '4月', '5月', '6月',
  '7月', '8月', '9月', '10月', '11月', '12月',
];

void openYearView(
  BuildContext context, {
  required EventRepository repository,
  required EventCategoryRepository categoryRepository,
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => YearViewPage(
        repository: repository,
        categoryRepository: categoryRepository,
      ),
    ),
  );
}

class YearViewPage extends StatefulWidget {
  const YearViewPage({
    super.key,
    required this.repository,
    required this.categoryRepository,
  });

  final EventRepository repository;
  final EventCategoryRepository categoryRepository;

  @override
  State<YearViewPage> createState() => _YearViewPageState();
}

class _YearViewPageState extends State<YearViewPage> {
  late int _year = DateTime.now().year;

  Future<void> _openDay(
    DateTime day,
    List<CalendarEvent> dayEvents,
    List<EventCategory> categories,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${day.year}年${day.month}月${day.day}日',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: dayEvents.isEmpty
                    ? const Center(child: Faint('この日の予定はありません'))
                    : ListView(
                        controller: scrollController,
                        children: [
                          for (final e in dayEvents)
                            ListTile(
                              leading: CircleAvatar(
                                radius: 6,
                                backgroundColor: Color(
                                  findCategory(
                                    categories.isEmpty
                                        ? defaultEventCategories
                                        : categories,
                                    e.categoryId,
                                  ).colorValue,
                                ),
                              ),
                              title: Text(e.title),
                              subtitle: e.isAllDay
                                  ? null
                                  : Text(
                                      '${e.start.hour.toString().padLeft(2, '0')}:'
                                      '${e.start.minute.toString().padLeft(2, '0')}',
                                    ),
                              onTap: e.isTravelEvent
                                  ? null
                                  : () {
                                      Navigator.pop(ctx);
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).push(
                                        MaterialPageRoute<void>(
                                          fullscreenDialog: true,
                                          builder: (_) => EventEditPage(
                                            repository: widget.repository,
                                            categoryRepository:
                                                widget.categoryRepository,
                                            event: e,
                                          ),
                                        ),
                                      );
                                    },
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('この日に予定を追加'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => EventEditPage(
                        repository: widget.repository,
                        categoryRepository: widget.categoryRepository,
                        initialStart: day,
                        initialAllDay: true,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('年間予定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _year -= 1),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('$_year年'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _year += 1),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<CalendarEvent>>(
        stream: widget.repository.watchAll(),
        builder: (context, eventSnap) {
          final events = eventSnap.data ?? const <CalendarEvent>[];
          return StreamBuilder<List<EventCategory>>(
            stream: widget.categoryRepository.watch(),
            builder: (context, catSnap) {
              final categories = catSnap.data ?? const <EventCategory>[];
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 600
                      ? 3
                      : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, i) {
                      final month = i + 1;
                      return _MiniMonth(
                        year: _year,
                        month: month,
                        today: today,
                        events: events,
                        categories: categories,
                        onTapDay: (day, dayEvents) =>
                            _openDay(day, dayEvents, categories),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.year,
    required this.month,
    required this.today,
    required this.events,
    required this.categories,
    required this.onTapDay,
  });

  final int year;
  final int month;
  final DateTime today;
  final List<CalendarEvent> events;
  final List<EventCategory> categories;
  final void Function(DateTime day, List<CalendarEvent> dayEvents) onTapDay;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // 月曜はじまり（weekday: 1=月 … 7=日）
    final leadingBlanks = firstOfMonth.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(
              _monthNames[month - 1],
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final w in _wd)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Column(
                children: [
                  for (var r = 0; r < rows; r++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var c = 0; c < 7; c++) _dayCell(context, r, c),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(BuildContext context, int r, int c) {
    final firstOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1;
    final cellIndex = r * 7 + c;
    final dayNum = cellIndex - leadingBlanks + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const Expanded(child: SizedBox.shrink());
    }
    final day = DateTime(year, month, dayNum);
    final isToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    final dayEvents = [for (final e in events) if (e.occursOn(day)) e];
    final dotColor = dayEvents.isEmpty
        ? null
        : Color(
            findCategory(
              categories.isEmpty ? defaultEventCategories : categories,
              dayEvents.first.categoryId,
            ).colorValue,
          );

    return Expanded(
      child: InkWell(
        onTap: () => onTapDay(day, dayEvents),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: isToday
              ? BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                )
              : null,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$dayNum', style: const TextStyle(fontSize: 10)),
              if (dotColor != null)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
