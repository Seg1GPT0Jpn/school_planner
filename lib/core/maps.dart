/// Google マップを開く（API は使わず、URL で開くだけ＝無料）
library;

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// 場所の文字から、Google マップの URL を作る
///
/// - 空 → マップのトップ（そこで探して、住所や URL をコピーできる）
/// - http(s) の URL（共有リンクなど）→ そのまま
/// - それ以外（施設名・住所）→ マップで検索
Uri mapUri(String place) {
  final t = place.trim();
  if (t.isEmpty) return Uri.https('www.google.com', '/maps');
  final asUrl = Uri.tryParse(t);
  if (asUrl != null && (asUrl.scheme == 'http' || asUrl.scheme == 'https')) {
    return asUrl;
  }
  return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': t});
}

/// Google マップを開く（スマホはマップアプリ、PC はブラウザの新しいタブ）
Future<void> openMap(BuildContext context, String place) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchUrl(mapUri(place), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(const SnackBar(content: Text('マップを開けませんでした')));
  }
}

/// タップするとマップが開く「場所」の行
class PlaceLink extends StatelessWidget {
  const PlaceLink(this.place, {super.key});

  final String place;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => openMap(context, place),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                place,
                style: TextStyle(
                  color: cs.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 14, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
