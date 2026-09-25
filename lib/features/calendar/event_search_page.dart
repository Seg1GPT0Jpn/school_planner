/// 予定検索・過去の予定の履歴 ― タイトル・場所・メモ・タグで予定を横断的に探す
library;

import 'package:material_ui/material_ui.dart';

import '../events/calendar_event.dart';
import '../events/event_category.dart';
import '../events/event_category_repository.dart';
import '../events/event_edit_page.dart';
import '../events/event_repository.dart';
import '../review/review_widgets.dart';

/// 予定検索・履歴ページを開く
void openEventSearch(
  BuildContext context, {
  required EventRepository repository,
  required EventCategoryRepository categoryRepository,
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => EventSearchPage(
        repository: repository,
        categoryRepository: categoryRepository,
      ),
    ),
  );
}

enum _TimeFilter { all, upcoming, past }

class EventSearchPage extends StatefulWidget {
  const EventSearchPage({
    super.key,
    required this.repository,
    required this.categoryRepository,
  });

  final EventRepository repository;
  final EventCategoryRepository categoryRepository;

  @override
  State<EventSearchPage> createState() => _EventSearchPageState();
}

class _EventSearchPageState extends State<EventSearchPage> {
  final _queryController = TextEditingController();
  String _query = '';
  _TimeFilter _timeFilter = _TimeFilter.all;
  String? _tagFilter;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  bool _matches(CalendarEvent e) {
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = [
        e.title,
        e.location ?? '',
        e.memo ?? '',
        ...e.tags,
      ].join(' ').toLowerCase();
      if (!hay.contains(q)) return false;
    }
    if (_tagFilter != null && !e.tags.contains(_tagFilter)) return false;
    final now = DateTime.now();
    switch (_timeFilter) {
      case _TimeFilter.all:
        return true;
      case _TimeFilter.upcoming:
        return !e.end.isBefore(now);
      case _TimeFilter.past:
        return e.end.isBefore(now);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('予定検索・履歴')),
      body: StreamBuilder<List<CalendarEvent>>(
        stream: widget.repository.watchAll(),
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <CalendarEvent>[];
          final allTags = <String>{for (final e in all) ...e.tags}.toList()
            ..sort();
          final results = all.where(_matches).toList()
            ..sort((a, b) => b.start.compareTo(a.start)); // 新しい順

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextField(
                      controller: _queryController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'タイトル・場所・メモ・タグで検索',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('すべて'),
                          selected: _timeFilter == _TimeFilter.all,
                          onSelected: (_) =>
                              setState(() => _timeFilter = _TimeFilter.all),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('これから'),
                          selected: _timeFilter == _TimeFilter.upcoming,
                          onSelected: (_) => setState(
                            () => _timeFilter = _TimeFilter.upcoming,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('過去（履歴）'),
                          selected: _timeFilter == _TimeFilter.past,
                          onSelected: (_) =>
                              setState(() => _timeFilter = _TimeFilter.past),
                        ),
                      ],
                    ),
                  ),
                  if (allTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          for (final tag in allTags) ...[
                            FilterChip(
                              avatar: const Icon(Icons.sell_outlined, size: 16),
                              label: Text(tag),
                              selected: _tagFilter == tag,
                              onSelected: (v) =>
                                  setState(() => _tagFilter = v ? tag : null),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(child: Faint('条件に合う予定はありません'))
                        : StreamBuilder<List<EventCategory>>(
                            stream: widget.categoryRepository.watch(),
                            builder: (context, catSnap) {
                              final categories =
                                  catSnap.data ?? const <EventCategory>[];
                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  8,
                                  4,
                                  8,
                                  24,
                                ),
                                itemCount: results.length,
                                itemBuilder: (context, i) {
                                  final e = results[i];
                                  final cat = findCategory(
                                    categories.isEmpty
                                        ? defaultEventCategories
                                        : categories,
                                    e.categoryId,
                                  );
                                  final isPast = e.end.isBefore(
                                    DateTime.now(),
                                  );
                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 6,
                                      backgroundColor: Color(cat.colorValue),
                                    ),
                                    title: Text(
                                      e.title,
                                      style: isPast
                                          ? TextStyle(
                                              color: Theme.of(context)
                                                  .disabledColor,
                                            )
                                          : null,
                                    ),
                                    subtitle: Text([
                                      '${e.start.year}/${e.start.month}/${e.start.day}'
                                          '${e.isAllDay ? '' : ' ${e.start.hour.toString().padLeft(2, '0')}:${e.start.minute.toString().padLeft(2, '0')}'}',
                                      if (e.location != null &&
                                          e.location!.isNotEmpty)
                                        e.location!,
                                      if (e.tags.isNotEmpty)
                                        e.tags.map((t) => '#$t').join(' '),
                                    ].join(' ・ ')),
                                    onTap: e.isTravelEvent
                                        ? null
                                        : () => Navigator.of(
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
                                          ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
