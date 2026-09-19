import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// タブ1つ分の情報（名前とアイコン）
class _TabItem {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// タブの一覧（この順番で並ぶ）
/// ※ router.dart の branches と同じ順番にすること
const List<_TabItem> _tabs = [
  _TabItem(label: 'ホーム', icon: Icons.home_outlined, selectedIcon: Icons.home),
  _TabItem(
    label: 'カレンダー',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
  ),
  _TabItem(
    label: '時間割',
    icon: Icons.table_chart_outlined,
    selectedIcon: Icons.table_chart,
  ),
  _TabItem(
    label: 'ToDo',
    icon: Icons.check_circle_outline,
    selectedIcon: Icons.check_circle,
  ),
  _TabItem(label: '目標', icon: Icons.flag_outlined, selectedIcon: Icons.flag),
];

/// この幅（ピクセル）以上なら PC 用のレイアウトにする
const double _wideLayoutBreakpoint = 600;

/// アプリ全体のタブの枠組み
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  /// go_router が用意してくれる「今どのタブを表示しているか」の管理役
  final StatefulNavigationShell navigationShell;

  /// タブが押されたときの処理
  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      // 今いるタブをもう一度押したら、そのタブの最初の画面に戻る
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= _wideLayoutBreakpoint;

    if (isWide) {
      // PC 用：左側にタブ
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onTabSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final tab in _tabs)
                  NavigationRailDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: Text(tab.label),
                  ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    // スマホ用：下側にタブ
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
