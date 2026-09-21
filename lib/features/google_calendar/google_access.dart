/// Google カレンダー連携の公開状態
///
/// Google の審査（OAuth の確認）が終わるまでは、Google Cloud の
/// 「OAuth 同意画面 ＞ テストユーザー」に登録した人（100人まで）しか接続できない。
/// 登録していない人が接続しようとすると、Google の画面で止められる（データは何も渡らない）。
///
/// だれのメールアドレスも、このアプリのコードには書かない。
/// テストユーザーの登録は Google Cloud のコンソールだけで行う。
library;

/// Google の審査が終わって「本番」にしたら true にする
const googleCalendarPublished = false;

/// 接続できないときの案内（審査が終わるまで）
const googleCalendarTestingNote =
    'Google カレンダー連携は、いま Google の審査中です。'
    '審査が終わるまでは、開発者がテストユーザーに登録した人だけ接続できます。'
    '使いたい人は、設定 ＞ プライバシーポリシー の連絡先から知らせてください。';
