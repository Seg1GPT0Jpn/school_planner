import 'package:material_ui/material_ui.dart';

/// 教科ごとの色（仮）
///
/// デザインの Phase で、手帳風の色に調整する。
Color categoryColor(String? category) {
  return switch (category) {
    '国語' => Colors.red.shade400,
    '数学' => Colors.blue.shade500,
    '英語' => Colors.purple.shade400,
    '理科' => Colors.green.shade600,
    '社会' => Colors.orange.shade700,
    '情報' => Colors.teal.shade500,
    '副教科' => Colors.blueGrey.shade400,
    _ => Colors.grey.shade500,
  };
}
