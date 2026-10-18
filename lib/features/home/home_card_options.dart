/// ホーム画面で表示・非表示を選べる項目の一覧
///
/// ここに載っている項目だけが「設定 ＞ ホーム画面に表示する項目」でON/OFFできる。
/// AppSettings.hiddenHomeCards は、この key を保存する。
library;

import 'package:flutter/material.dart' show IconData, Icons;

class HomeCardOption {
  const HomeCardOption({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String key;
  final String label;
  final String description;
  final IconData icon;
}

const List<HomeCardOption> homeCardOptions = [
  HomeCardOption(
    key: 'event_search',
    label: '予定検索・履歴',
    description: 'タグ・場所・メモで予定を探す',
    icon: Icons.manage_search,
  ),
  HomeCardOption(
    key: 'year_view',
    label: '年間予定',
    description: '12か月をひと目で見渡す',
    icon: Icons.calendar_view_month,
  ),
  HomeCardOption(
    key: 'birthdays',
    label: '誕生日',
    description: '近づいた誕生日を表示',
    icon: Icons.cake_outlined,
  ),
  HomeCardOption(
    key: 'practice_tools',
    label: 'チューナー',
    description: 'メトロノーム・チューナー・ドローン・ピアノ・練習ログ',
    icon: Icons.music_note,
  ),
  HomeCardOption(
    key: 'notes',
    label: 'メモ',
    description: 'テキスト・Markdown・チェックリスト',
    icon: Icons.edit_note,
  ),
  HomeCardOption(
    key: 'quest',
    label: 'つづりクエスト',
    description: 'クエストで勉強した時間・問題数・苦手な単元',
    icon: Icons.sports_esports_outlined,
  ),
  HomeCardOption(
    key: 'flashcards',
    label: '暗記カード',
    description: '単語帳・一問一答',
    icon: Icons.style_outlined,
  ),
  HomeCardOption(
    key: 'groups',
    label: 'グループ',
    description: '部活や友達とお知らせ・共有ToDo',
    icon: Icons.groups_outlined,
  ),
  HomeCardOption(
    key: 'money',
    label: 'お小遣い管理',
    description: '収支の記録・予算・グラフ',
    icon: Icons.savings_outlined,
  ),
  HomeCardOption(
    key: 'ai_chat',
    label: 'AIチャット',
    description: '要約・添削・翻訳・なんでも質問',
    icon: Icons.chat_outlined,
  ),
  HomeCardOption(
    key: 'score',
    label: '楽譜作成',
    description: '五線譜に音符を入力して作曲・再生',
    icon: Icons.piano,
  ),
];
