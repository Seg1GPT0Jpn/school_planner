/// 設定 ＞ 自宅・学校の場所と移動
library;

import 'package:material_ui/material_ui.dart';

import '../../core/maps.dart';
import '../settings/preferences_pages.dart';
import '../settings/settings_scope.dart';
import 'geocoder.dart';
import 'travel.dart';

/// 選べる「余裕」（分）
const bufferChoices = [0, 5, 10, 15, 20, 30];

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  final _home = TextEditingController();
  final _school = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final s = SettingsScope.of(context);
    _home.text = s.homeAddress;
    _school.text = s.schoolAddress;
  }

  @override
  void dispose() {
    _home.dispose();
    _school.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(t, style: tt.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('自宅・学校の場所と移動')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  '場所を登録すると、予定に「場所」が入っているときに、'
                  'かかる時間の目安と「何時ごろに出ればよいか」が出ます。',
                  style: tt.bodyMedium,
                ),
              ),
              header('自宅'),
              _PlaceEditor(
                controller: _home,
                hint: '例：藤沢市鵠沼海岸1丁目（町名まででもOK）',
                savedAddress: s.homeAddress,
                savedPoint: s.homePoint,
                onFound: (address, p) => saveSettings(
                  context,
                  s.copyWith(homeAddress: address, homePoint: p),
                ),
                onClear: () {
                  _home.clear();
                  saveSettings(context, s.copyWith(clearHome: true));
                },
              ),
              header('学校（職場）'),
              _PlaceEditor(
                controller: _school,
                hint: '例：学校名や住所',
                savedAddress: s.schoolAddress,
                savedPoint: s.schoolPoint,
                onFound: (address, p) => saveSettings(
                  context,
                  s.copyWith(schoolAddress: address, schoolPoint: p),
                ),
                onClear: () {
                  _school.clear();
                  saveSettings(context, s.copyWith(clearSchool: true));
                },
              ),
              header('移動'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<TravelMode>(
                  segments: const [
                    ButtonSegment(
                      value: TravelMode.transit,
                      icon: Icon(Icons.train_outlined),
                      label: Text('電車・バス'),
                    ),
                    ButtonSegment(
                      value: TravelMode.car,
                      icon: Icon(Icons.directions_car_outlined),
                      label: Text('車（送迎）'),
                    ),
                  ],
                  selected: {s.travelMode},
                  onSelectionChanged: (v) =>
                      saveSettings(context, s.copyWith(travelMode: v.first)),
                ),
              ),
              ListTile(
                title: const Text('出発の余裕'),
                subtitle: const Text('着きたい時刻より、これだけ早く出る'),
                trailing: Text(
                  s.travelBufferMinutes == 0
                      ? 'なし'
                      : '${s.travelBufferMinutes}分',
                ),
                onTap: () async {
                  final v = await pickOne<int>(
                    context,
                    title: '出発の余裕',
                    options: bufferChoices,
                    current: s.travelBufferMinutes,
                    label: (m) => m == 0 ? 'なし' : '$m分',
                  );
                  if (v != null && context.mounted) {
                    await saveSettings(
                      context,
                      s.copyWith(travelBufferMinutes: v),
                    );
                  }
                },
              ),
              SwitchListTile(
                title: const Text('放課後の予定は学校から出発'),
                subtitle: const Text('授業のある日に、授業が終わってから始まる予定は「学校から」で計算します'),
                value: s.departFromSchool,
                onChanged: (v) =>
                    saveSettings(context, s.copyWith(departFromSchool: v)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  '・時間は「まっすぐの距離」から出した目安です。'
                  '電車の時刻や渋滞は、予定の画面の「Google マップで経路を見る」で確かめてください。\n'
                  '・自宅・学校の住所と予定の「場所」は、位置を調べるときだけ'
                  '国土地理院と OpenStreetMap に送ります（名前やメールは送りません）。'
                  '保存先はあなた専用の場所で、ほかの人には見えません。\n'
                  '・地図データ © OpenStreetMap contributors',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 住所を入れて「位置を調べる」
class _PlaceEditor extends StatefulWidget {
  const _PlaceEditor({
    required this.controller,
    required this.hint,
    required this.savedAddress,
    required this.savedPoint,
    required this.onFound,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final String savedAddress;
  final LatLng? savedPoint;
  final void Function(String address, LatLng point) onFound;
  final VoidCallback onClear;

  @override
  State<_PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<_PlaceEditor> {
  bool _busy = false;
  String? _message;
  String? _foundLabel;

  Future<void> _search() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await Geocoder.lookup(text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r == null) {
        _message = '見つかりませんでした。市区町村から入れてみてください（例：藤沢市〇〇1丁目）';
      } else {
        _foundLabel = r.label;
      }
    });
    if (r != null) widget.onFound(text, r.point);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final p = widget.savedPoint;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: widget.hint,
              suffixIcon: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: '位置を調べる',
                      onPressed: _search,
                    ),
            ),
          ),
          const SizedBox(height: 6),
          if (_message != null)
            Text(_message!, style: tt.bodySmall?.copyWith(color: cs.error))
          else if (p == null)
            Text(
              'まだ登録していません（入れたら 🔍 で位置を調べます）',
              style: tt.bodySmall?.copyWith(color: cs.outline),
            )
          else
            Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '登録ずみ：${_foundLabel ?? widget.savedAddress}',
                    style: tt.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => openMap(context, p.text),
                  child: const Text('地図で確かめる'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '消す',
                  onPressed: () {
                    setState(() => _foundLabel = null);
                    widget.onClear();
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
