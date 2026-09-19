import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:school_planner/features/events/event_category.dart';
import 'package:school_planner/widgets/color_palette_picker.dart';

void main() {
  group('256色の見本', () {
    test('16段 × 16列', () {
      expect(colorPalette.length, 16);
      for (final row in colorPalette) {
        expect(row.length, 16);
      }
    });

    test('256色がすべて違う色', () {
      final values = {
        for (final row in colorPalette)
          for (final c in row) c.toARGB32(),
      };
      expect(values.length, 256);
    });

    test('暗い色には白い文字、明るい色には黒い文字', () {
      expect(readableTextColor(Colors.black), Colors.white);
      expect(readableTextColor(Colors.white), Colors.black87);
    });
  });

  group('最初のカテゴリ', () {
    test('ID が重複しておらず、「その他」がある', () {
      final ids = defaultEventCategories.map((c) => c.id).toSet();
      expect(ids.length, defaultEventCategories.length);
      expect(ids, contains(EventCategory.otherId));
    });

    test('「その他」だけは削除できない', () {
      for (final c in defaultEventCategories) {
        expect(c.isDeletable, c.id != EventCategory.otherId);
      }
    });

    test('見つからない ID は「その他」になる', () {
      expect(findCategory(defaultEventCategories, 'nothing').id, 'other');
    });
  });
}
