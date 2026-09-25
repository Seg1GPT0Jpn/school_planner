/// ホーム画面に表示する項目を選ぶ画面
library;

import 'package:material_ui/material_ui.dart';

import '../home/home_card_options.dart';
import '../review/review_widgets.dart';
import 'preferences_pages.dart';
import 'settings_scope.dart';

class HomeVisibilityPage extends StatelessWidget {
  const HomeVisibilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);

    Future<void> toggle(String key, bool visible) async {
      final hidden = List<String>.from(s.hiddenHomeCards);
      if (visible) {
        hidden.remove(key);
      } else if (!hidden.contains(key)) {
        hidden.add(key);
      }
      await saveSettings(context, s.copyWith(hiddenHomeCards: hidden));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ホーム画面に表示する項目')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Faint('OFFにした項目は、ホーム画面のカードに出なくなります（機能自体は消えません）'),
              ),
              for (final o in homeCardOptions)
                SwitchListTile(
                  secondary: Icon(o.icon),
                  title: Text(o.label),
                  subtitle: Text(o.description),
                  value: s.showHomeCard(o.key),
                  onChanged: (v) => toggle(o.key, v),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
