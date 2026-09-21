/// ③〜⑫：ログインしたあとの案内をまとめて進行する画面
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../timetable/school_periods.dart';
import '../timetable/timetable_repository.dart';
import 'completion_step.dart';
import 'onboarding_repository.dart';
import 'onboarding_schedule_flow.dart';
import 'timetable_intro_step.dart';
import 'tutorial_cards_step.dart';
import 'welcome_consent_page.dart';

enum _Phase { welcome, schedule, timetable, tutorial, completion }

class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _onboardingRepo = OnboardingRepository(uid: _uid);
  late final _timetableRepo = TimetableRepository(uid: _uid);

  _Phase _phase = _Phase.welcome;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, _Phase next) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      // 保存に失敗しても、案内そのものは止めない（あとで設定から直せる）
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _phase = next;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    switch (_phase) {
      case _Phase.welcome:
        return WelcomeConsentPage(
          onAgreed: () => _run(_onboardingRepo.markAgreed, _Phase.schedule),
        );
      case _Phase.schedule:
        return OnboardingScheduleFlow(
          onDone: (ScheduleConfig config) => _run(
            () => _timetableRepo.saveScheduleConfig(config),
            _Phase.timetable,
          ),
        );
      case _Phase.timetable:
        return TimetableIntroStep(
          onNext: () => setState(() => _phase = _Phase.tutorial),
        );
      case _Phase.tutorial:
        return TutorialCardsStep(
          onDone: () => _run(
            () => _onboardingRepo.markTutorialDone(skipped: false),
            _Phase.completion,
          ),
        );
      case _Phase.completion:
        return CompletionStep(
          onGoHome: () async {
            setState(() => _busy = true);
            try {
              await _onboardingRepo.markCompleted();
            } catch (_) {
              // 失敗しても go_router の redirect が未完了として扱うだけなので、
              // とりあえずホームへの遷移は試みる
            }
            if (mounted) context.go('/');
          },
        );
    }
  }
}
