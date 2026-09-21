# つづり — 引継ぎ資料（Claude → 他のAI用）

最終更新：2026-09-21（Claude Sonnet 5 / Opus 5 とのセッションより）

この資料は、Claude の利用制限に達したときなどに、**Gemini など別のAIに開発を引き継ぐため**のものです。
新しいAIとの会話のはじめに、このファイルをまるごと貼るか添付してください。

---

## 1. このアプリについて

- **名前**：つづり
- **なに**：高校生の学校生活を、時間割・予定・テスト・目標・持ち物までひとつにまとめる個人用アプリ
- **作っている人**：かず（高校生。留守番ど〈19人編成の学生バンド〉の学生指揮者、トランペット歴10年）
- **今の段階**：個人利用から、同じ学校の人にも使ってもらう「正式リリース」段階に入ったところ
- **返答の言語**：かずとのやりとりは**必ず日本語**。コード内のコメントも日本語。

---

## 2. 技術構成

| 項目 | 内容 |
|---|---|
| フレームワーク | Flutter 3.47.5 / Dart 3.13（null-aware要素 `?x`、if-caseの分岐、レコード型、パターンマッチが使える） |
| バックエンド | Firebase（Authentication・Cloud Firestore・Hosting） |
| Firebase プロジェクトID | `school-planner-30628` |
| Googleアカウント | kzmsegawa@gmail.com（開発者） |
| ローカルパス | `C:\develop\projects\school_planner`（Windows） |
| UIライブラリ | `material_ui`（Material 3ベース） |
| 主なパッケージ | `go_router`, `cloud_firestore`, `firebase_auth`, `flutter_local_notifications`, `timezone`, `http`, `url_launcher`, `home_widget`, `file_picker`, `share_plus` |
| Web公開先 | `https://school-planner-30628.web.app` |
| Android実機テスト | Pixel を `release.ps1 <ip>:<port> "メモ"` でワイヤレスデバッグ配信（ポートは毎回変わる） |

### 確認コマンド（変更のたびに実行）
```
dart format lib test
flutter analyze
flutter test
flutter run -d chrome     # 画面の確認
```

### Web公開
```
flutter build web --release
firebase deploy --only hosting,firestore:rules
```
※ `firestore.rules` は「ログインした本人のデータだけ読み書きできる」設定ずみ。deploy すると誰でもログインできるようになる（見えるのは自分のデータだけ）。

---

## 3. ディレクトリ構成（`lib/features/` 配下）

```
app/            ルーティング・テーマ・アプリ全体の入れもの
core/           日付フォーマット・祝日データ・地図リンク・タイムゾーン
features/
  auth/         ログイン（Googleログインのみ）
  calendar/     カレンダー画面（月・週・スケジュール表示、時間割グリッド）
  events/       予定（CalendarEvent）の作成・編集・保存
  timetable/    時間割・時程（Ⅰ週/Ⅱ週、通常/短縮/試験日課）★核となる機能
  travel/       自宅・学校の位置と移動時間の目安（新機能）
  weather/      天気予報・休校（自宅待機）予測
  school_tests/ テスト・小テストの管理
  review/       週間・月間・学期レビュー、テストカルテ、学校イベント
  grades/       成績・偏差値（標準偏差からの自動計算つき）
  goals/        目標・勉強計画
  study/        勉強時間（ポモドーロ）
  todo/         ToDo
  recurring/    塾・部活などの定期予定
  belongings/   持ち物リスト
  google_calendar/  Googleカレンダー連携（審査中のため案内表示つき）
  notifications/    通知（つづり本体・静音の2チャンネル）
  settings/     設定全般（表示・言語・予定・通知・タイムゾーン・オフライン・インポートエクスポート）
  widget/       ホーム画面ウィジェット（Android home_widget連携）
  home/         ホーム画面（今日の司令塔）
```

---

## 4. 設計上の重要な決まりごと

### 4-1. 時間割・時程まわり（`timetable/school_periods.dart`）
- `ScheduleConfig` が時程の唯一の定義（時限の時刻・曜日ごとのコマ数・昼休み・短縮/試験日課・Ⅰ週Ⅱ週の有無）。
- `SchoolPeriods`（static facade）がアプリ全体から参照する窓口。`TimetableRepository._build()` で
  Firestoreの `settings/school_schedule` を読んで `SchoolPeriods.config` を入れ替える。
- 何も設定していない人は `ScheduleConfig.standard`（今の学校＝70分授業・月火木5コマ・水金4コマ・
  昼休み3限後・Ⅰ週Ⅱ週あり）がデフォルト。**後方互換が最優先**（既存ユーザーの動作を変えない）。
- `WeekCycleCalculator(enabled: bool)` で「Ⅰ週Ⅱ週を使わない」設定にも対応ずみ。

### 4-2. 設定（`settings/app_settings.dart`）
- `AppSettings` は不変（immutable）クラス。`copyWith` で更新、`toMap`/`fromMap` でFirestore保存。
- `SettingsScope.of(context)` でどの画面からも参照できる（InheritedWidget）。
- 壊れた値・知らない値は必ず「はじめの設定」にフォールバックする（`fromMap` で範囲チェック）。

### 4-3. Firestore構造
```
users/{uid}/
  settings/app              ← AppSettings
  settings/school_schedule  ← ScheduleConfig（時程）
  events/{id}                CalendarEvent
  subjects/{id}               科目
  timetable_versions/{id}     時間割の切り替え履歴
  timetable_overrides/{date}  特定日の時限変更
  test_reviews/{id}, reviews/{id}, event_links/{id}
  places/{id}                 住所→緯度経度の検索キャッシュ（自宅・学校・予定の場所）
```
- **セキュリティルール**：`request.auth != null && request.auth.uid == userId` のみ（自分のデータだけ読み書き可）。
- APIキー（Google Maps / 天気など）は**クライアントに一切置かない**。地図はURL起動のみ、位置検索は無料の国土地理院／OpenStreetMapを直接呼ぶ。

### 4-4. 外部サービス（無料・APIキー不要）
| サービス | 用途 |
|---|---|
| 気象庁（`bosai/warning/data/r8/...`） | 警報・注意報（2026-05-29に新エンドポイントへ移行済み） |
| Open-Meteo | 天気予報（学校の固定座標だけ使用） |
| 国土地理院 地名検索 → 見つからなければ OpenStreetMap Nominatim | 住所・場所の緯度経度検索 |
| Google マップ | URL起動のみ（APIキー不使用） |
| Google カレンダー | OAuth連携（審査中。`google_access.dart` の `googleCalendarPublished` フラグで案内表示を制御） |

### 4-5. 開発ワークフロー（Claudeとの間で確立した進め方）
- ファイルは**全文置き換え**で作業（部分編集より確実）
- 変更のたびに `dart format → flutter analyze → flutter test → flutter run -d chrome` で確認
- 大きな機能は複数ファイルにまたがるので、依存関係の順（データモデル→リポジトリ→画面）で進める

---

## 5. 現在の状況（2026-09-21時点）

### 完了ずみ
- 基本機能一式（時間割・予定・テスト・目標・持ち物・レビュー・成績・天気・休校予測・ウィジェット・通知・設定全般）
- 時程を自由に設定できる機能（時限の時刻・曜日ごとのコマ数・Ⅰ週Ⅱ週の有無・昼休み・短縮/試験日課）
- 自宅・学校の位置登録と、予定の場所までの移動時間・出発時刻の目安表示
- Web版の公開設定・プライバシーポリシー・Firestoreルールの本番化（すでに `firebase deploy` 完了）

### 保留・今後
- **Google カレンダー連携の本審査**：Google Cloud で「テストユーザー」登録中の段階。本番公開するには
  OAuth同意画面の審査（ブランディング設定・ドメイン所有権確認・説明動画の提出）が必要。
  審査が通ったら `lib/features/google_calendar/google_access.dart` の `googleCalendarPublished` を `true` にする。
- **Android版のPlay Store配信**：内部テスト/クローズドテストでの配布は未着手（今はPixel実機への直接インストールのみ）。
- ホーム画面ウィジェットは今日の予定を最大6件までしか表示できない（Kotlin側の制約）。

---

## 6. 別のAIに引き継ぐときの伝え方（例）

新しい会話の最初に、このファイルの内容に加えて次を伝えるとスムーズです。

> 「つづり」という Flutter + Firebase の個人開発アプリの続きをお願いします。
> 添付の HANDOFF.md がこれまでの設計・進め方のまとめです。読んでから、
> 「〇〇を直したい／足したい」の内容に入ってください。
> ファイルは全文置き換えで進めて、変更ごとに `dart format lib test` → `flutter analyze` → `flutter test` で確認してください。
> 返答は日本語でお願いします。

必要であれば、該当する `lib/features/xxx/*.dart` を一緒に貼るかアップロードしてください
（Gemini はプロジェクト全体を自動では見られないため、関係するファイルを渡す必要があります）。

---

## 7. 困ったときの確認先

- Firebase コンソール：https://console.firebase.google.com/project/school-planner-30628
- Google Cloud コンソール（OAuth同意画面・テストユーザー登録）：https://console.cloud.google.com/apis/credentials/consent?project=school-planner-30628
- 公開URL：https://school-planner-30628.web.app
- プライバシーポリシー：https://school-planner-30628.web.app/privacy.html
