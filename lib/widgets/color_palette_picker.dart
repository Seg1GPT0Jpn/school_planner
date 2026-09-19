import 'package:material_ui/material_ui.dart';

/// 色合いの数（横の列。右端にグレーを1列足して16列）
const int _hueCount = 15;

/// 明るさの段数（縦の段）
const int _rowCount = 16;

/// 16 × 16 = 256色の見本
final List<List<Color>> colorPalette = _buildPalette();

List<List<Color>> _buildPalette() {
  return [
    for (var r = 0; r < _rowCount; r++)
      [
        // 上ほど淡く（明るさ 0.92）、下ほど濃く（明るさ 0.12）
        for (var h = 0; h < _hueCount; h++)
          HSLColor.fromAHSL(
            1,
            h * (360 / _hueCount),
            0.65,
            0.92 - r * (0.80 / (_rowCount - 1)),
          ).toColor(),
        // 右端はグレー
        HSLColor.fromAHSL(
          1,
          0,
          0,
          0.92 - r * (0.80 / (_rowCount - 1)),
        ).toColor(),
      ],
  ];
}

/// その色の上に乗せる文字の色（暗い色なら白、明るい色なら黒）
Color readableTextColor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}

/// 256色から1色を選ぶダイアログ（選ばなければ null）
Future<Color?> showColorPalettePicker(BuildContext context, {Color? initial}) {
  return showDialog<Color>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('色を選ぶ'),
        // 画面が小さいときは、マス目全体を縮めて収める
        content: FittedBox(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in colorPalette)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final color in row)
                      _Swatch(
                        color: color,
                        isSelected: initial?.toARGB32() == color.toARGB32(),
                        onTap: () => Navigator.of(context).pop(color),
                      ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
        ],
      );
    },
  );
}

/// 色見本1マス
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mark = readableTextColor(color);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: isSelected ? Border.all(color: mark, width: 2) : null,
        ),
        child: isSelected ? Icon(Icons.check, size: 14, color: mark) : null,
      ),
    );
  }
}
