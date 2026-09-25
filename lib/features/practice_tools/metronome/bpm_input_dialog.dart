/// BPMを数値で直接入力するダイアログ
library;

import 'package:material_ui/material_ui.dart';

/// [current] を初期値にしたダイアログを開き、確定されたBPM（[min]〜[max]の範囲に
/// 丸めたもの）を返す。キャンセルされたら null を返す。
Future<int?> showBpmInputDialog(
  BuildContext context, {
  required int current,
  int min = 30,
  int max = 300,
}) {
  final controller = TextEditingController(text: '$current');
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('BPMを入力'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
        decoration: InputDecoration(
          suffixText: 'BPM',
          helperText: '$min〜$max の範囲で入力してください',
        ),
        onSubmitted: (v) {
          final n = int.tryParse(v.trim());
          if (n != null) Navigator.pop(context, n.clamp(min, max).toInt());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            final n = int.tryParse(controller.text.trim());
            Navigator.pop(context, n?.clamp(min, max).toInt());
          },
          child: const Text('決定'),
        ),
      ],
    ),
  );
}
