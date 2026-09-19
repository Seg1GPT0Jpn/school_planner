import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Flutter の準備が整うのを待つ
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase に接続する（接続が終わるまで待つ）
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const App());
}
