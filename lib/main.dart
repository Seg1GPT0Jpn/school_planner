import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'features/notifications/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Flutter の準備が整うのを待つ
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase に接続する（接続が終わるまで待つ）
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 先に画面を表示する。音の設定（下）は画面が出た「後」でも間に合うし、
  // 万が一失敗・タイムアウトしても起動そのものを止めないようにする。
  runApp(const App());

  // スマホ（Android/iOS）は、何もしないと「新しい音が鳴ると前の音が止まる」
  // 設定になっている（1音しか鳴らせない）。メトロノーム・ドローン・ピアノなど、
  // 複数の音を同時に鳴らす機能があるので、アプリ全体で音を重ねて鳴らせるように
  // しておく（PC・Webはもともと重ねて鳴らせるので影響しない）。
  //
  // これはネイティブ側とやり取りするプラットフォームチャンネル呼び出しで、
  // 機種によっては応答が返ってこないことがある。以前はこれを runApp() より
  // 前で await していたため、応答が返らないといつまでも画面が表示されない
  // （起動しない）不具合があった。runApp() の後ろに動かし、さらに
  // タイムアウトと失敗時のもみ消しを付けて、万一失敗しても起動には
  // 影響しないようにしている。
  unawaited(_setUpAudioContext());

  // アラーム（通知）をタップしてアプリが起動された場合は、アラーム画面を出す
  unawaited(NotificationService.instance.checkLaunchedByAlarm());
}

Future<void> _setUpAudioContext() async {
  try {
    await AudioPlayer.global
        .setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: false,
              stayAwake: false,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.assistanceSonification,
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: const {AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        )
        .timeout(const Duration(seconds: 5));
  } catch (_) {
    // 音を重ねて鳴らす設定に失敗しても、アプリの起動・利用は続けられる。
    // （最悪の場合、メトロノーム等で音が1つしか鳴らないだけ）
  }
}
