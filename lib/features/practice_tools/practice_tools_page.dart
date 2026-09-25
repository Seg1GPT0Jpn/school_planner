/// チューナー（メトロノーム・チューナー・解析・ロングトーン・イントネーションマップ・
/// スペクトラム・ドローン・ピアノ・練習ログ・開発者向け）
library;

import 'package:material_ui/material_ui.dart';

import 'analysis_tab.dart';
import 'dev/dev_tools_tab.dart';
import 'drone_tab.dart';
import 'intonation_map_tab.dart';
import 'long_tone_tab.dart';
import 'metronome_tab.dart';
import 'piano_tab.dart';
import 'practice_timer_tab.dart';
import 'spectrum_tab.dart';
import 'tuner_tab.dart';

void openPracticeTools(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const PracticeToolsPage()));
}

class PracticeToolsPage extends StatelessWidget {
  const PracticeToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 10,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('チューナー'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'メトロノーム', icon: Icon(Icons.timer_outlined)),
              Tab(text: 'チューナー', icon: Icon(Icons.graphic_eq)),
              Tab(text: '解析', icon: Icon(Icons.show_chart)),
              Tab(text: 'ロングトーン', icon: Icon(Icons.spa_outlined)),
              Tab(text: '音程マップ', icon: Icon(Icons.grid_on_outlined)),
              Tab(text: 'スペクトラム', icon: Icon(Icons.equalizer)),
              Tab(text: 'ドローン', icon: Icon(Icons.music_note)),
              Tab(text: 'ピアノ', icon: Icon(Icons.piano)),
              Tab(text: '練習ログ', icon: Icon(Icons.history)),
              Tab(text: '開発者向け', icon: Icon(Icons.science_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MetronomeTab(),
            TunerTab(),
            AnalysisTab(),
            LongToneTab(),
            IntonationMapTab(),
            SpectrumTab(),
            DroneTab(),
            PianoTab(),
            PracticeTimerTab(),
            DevToolsTab(),
          ],
        ),
      ),
    );
  }
}
