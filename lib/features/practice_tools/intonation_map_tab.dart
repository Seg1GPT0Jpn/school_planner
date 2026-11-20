/// イントネーションマップ：楽器ごとに「どの音が高くなりやすいか」をヒートマップで見る
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../review/review_widgets.dart';
import 'analysis/intonation_map.dart';
import 'instruments/instrument_profile.dart';
import 'music_theory.dart';

class IntonationMapTab extends StatefulWidget {
  const IntonationMapTab({super.key});

  @override
  State<IntonationMapTab> createState() => _IntonationMapTabState();
}

class _IntonationMapTabState extends State<IntonationMapTab> {
  InstrumentProfile _instrument = instrumentProfiles.first;

  Color _heatColor(ColorScheme cs, double cents) {
    final a = cents.abs().clamp(0, 20) / 20; // 0〜1（20セントで最大）
    final base = cents >= 0 ? const Color(0xFFE53935) : const Color(0xFF1E88E5);
    return Color.lerp(cs.surfaceContainerHighest, base, 0.15 + a * 0.65)!;
  }

  /// 12音を一覧できる、ひと目でわかるヒートマップ（2行×6列）
  Widget _heatmapGrid(ColorScheme cs, Map<int, NoteIntonationStat> map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 0.85,
          children: [
            for (var pc = 0; pc < 12; pc++)
              Container(
                decoration: BoxDecoration(
                  color: map[pc] == null
                      ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
                      : _heatColor(cs, map[pc]!.meanCents),
                  borderRadius: BorderRadius.circular(6),
                  border: map[pc] != null && !map[pc]!.isReliable
                      ? Border.all(color: cs.outline, width: 1)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      noteNameFor(pc, NotationSystem.english),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (map[pc] != null)
                      Text(
                        '${map[pc]!.meanCents >= 0 ? '+' : ''}'
                        '${map[pc]!.meanCents.toStringAsFixed(0)}¢',
                        style: const TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _legendDot(const Color(0xFF1E88E5), '低め'),
            _legendDot(cs.surfaceContainerHighest, 'ぴったり付近'),
            _legendDot(const Color(0xFFE53935), '高め'),
            Text('枠あり＝記録3回未満（参考値）', style: TextStyle(color: cs.outline, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'ロングトーン分析で「記録する」を押すたびに、この楽器のこの音の平均セントが積み上がります。'
          '色が濃いほど、標準からのズレが大きい音です（赤＝高くなりがち、青＝低くなりがち）。',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in instrumentProfiles)
              ChoiceChip(
                label: Text(p.name),
                selected: _instrument.id == p.id,
                onSelected: (_) => setState(() => _instrument = p),
              ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<Map<int, NoteIntonationStat>>(
          stream: IntonationMapRepository(
            uid: uid,
            instrumentId: _instrument.id,
          ).watch(),
          builder: (context, snapshot) {
            final map = snapshot.data ?? {};
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (map.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Faint('まだ記録がありません。「ロングトーン分析」タブで音を伸ばして記録してみてください。'),
              );
            }
            return Column(
              children: [
                _heatmapGrid(cs, map),
                const SizedBox(height: 20),
                Text('内訳（音ごとの詳細）', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (var pc = 0; pc < 12; pc++)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: map[pc] == null
                          ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
                          : _heatColor(cs, map[pc]!.meanCents),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            noteNameFor(pc, NotationSystem.english),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: map[pc] == null
                              ? const Text('記録なし')
                              : Text(
                                  '平均 ${map[pc]!.meanCents >= 0 ? '+' : ''}'
                                  '${map[pc]!.meanCents.toStringAsFixed(1)}¢'
                                  '（${map[pc]!.sampleCount}回${map[pc]!.isReliable ? '' : '・参考値'}）',
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
