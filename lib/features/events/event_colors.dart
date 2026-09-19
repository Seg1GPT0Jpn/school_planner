import 'package:material_ui/material_ui.dart';

import 'calendar_event.dart';

/// 予定のカテゴリごとの色（仮。デザインの Phase で調整する）
Color eventCategoryColor(EventCategory category) {
  return switch (category) {
    EventCategory.school => Colors.indigo.shade400,
    EventCategory.club => Colors.orange.shade600,
    EventCategory.study => Colors.green.shade600,
    EventCategory.personal => Colors.pink.shade300,
    EventCategory.important => Colors.red.shade600,
    EventCategory.other => Colors.blueGrey.shade400,
  };
}
