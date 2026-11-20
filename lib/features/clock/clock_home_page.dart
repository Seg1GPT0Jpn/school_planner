/// アラーム・タイマー・ストップウォッチ・お休み時間のまとめ画面
library;

import 'package:material_ui/material_ui.dart';

import 'alarm_page.dart';
import 'bedtime_page.dart';
import 'stopwatch_page.dart';
import 'timer_page.dart';

void openClockHub(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const ClockHomePage()));
}

class ClockHomePage extends StatefulWidget {
  const ClockHomePage({super.key});

  @override
  State<ClockHomePage> createState() => _ClockHomePageState();
}

class _ClockHomePageState extends State<ClockHomePage> {
  int _tab = 0;

  static const _titles = ['アラーム', 'タイマー', 'ストップウォッチ', 'お休み時間'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_tab])),
      body: switch (_tab) {
        0 => const AlarmListView(),
        1 => const TimerTab(),
        2 => const StopwatchTab(),
        _ => const BedtimeTab(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.alarm), label: 'アラーム'),
          NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'タイマー'),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.av_timer),
            label: 'ストップウォッチ',
          ),
          NavigationDestination(icon: Icon(Icons.nights_stay_outlined), label: 'お休み時間'),
        ],
      ),
    );
  }
}
