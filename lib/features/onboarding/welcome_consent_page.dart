/// ③「ようこそつづりへ」→ 利用規約・プライバシーポリシーへの同意
library;

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_links.dart';

class WelcomeConsentPage extends StatefulWidget {
  const WelcomeConsentPage({super.key, required this.onAgreed});

  /// 同意して次へ進むときに呼ばれる
  final VoidCallback onAgreed;

  @override
  State<WelcomeConsentPage> createState() => _WelcomeConsentPageState();
}

class _WelcomeConsentPageState extends State<WelcomeConsentPage> {
  bool _agreedTerms = false;
  bool _agreedPrivacy = false;

  bool get _canProceed => _agreedTerms && _agreedPrivacy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              children: [
                Icon(Icons.waving_hand, size: 48, color: cs.primary),
                const SizedBox(height: 16),
                Text('ようこそ、つづりへ', style: tt.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'はじめに、このアプリを使う上でのお約束を確認してください。',
                  style: tt.bodyMedium?.copyWith(color: cs.outline),
                ),
                const SizedBox(height: 28),
                Card(
                  child: CheckboxListTile(
                    value: _agreedTerms,
                    onChanged: (v) =>
                        setState(() => _agreedTerms = v ?? false),
                    title: const Text('利用規約に同意する'),
                    subtitle: InkWell(
                      onTap: () => launchUrl(
                        termsOfServiceUri,
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        '利用規約を読む',
                        style: TextStyle(
                          color: cs.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: CheckboxListTile(
                    value: _agreedPrivacy,
                    onChanged: (v) =>
                        setState(() => _agreedPrivacy = v ?? false),
                    title: const Text('プライバシーポリシーに同意する'),
                    subtitle: InkWell(
                      onTap: () => launchUrl(
                        privacyPolicyUri,
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        'プライバシーポリシーを読む',
                        style: TextStyle(
                          color: cs.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'このアプリは個人が開発・運営しているものです。'
                  '規約・ポリシーも「正式な法律文書」というより、使う上でのお約束として書いています。',
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _canProceed ? widget.onAgreed : null,
                  child: const Text('同意してはじめる'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
