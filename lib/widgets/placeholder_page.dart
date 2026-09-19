import 'package:material_ui/material_ui.dart';

/// まだ作っていない画面の代わりに表示する仮の画面
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.icon});

  /// 画面のタイトル（例：ホーム）
  final String title;

  /// 画面の中央に表示するアイコン
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '「$title」は準備中です',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
