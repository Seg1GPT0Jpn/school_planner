/// インポート／エクスポート（.ics）
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../events/calendar_event.dart';
import '../events/event_repository.dart';
import '../google_calendar/google_sync.dart';
import 'event_ics.dart';
import 'ics.dart';
import 'settings_scope.dart';

class ImportExportPage extends StatefulWidget {
  const ImportExportPage({super.key});

  @override
  State<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends State<ImportExportPage> {
  final _repository = EventRepository(
    uid: FirebaseAuth.instance.currentUser!.uid,
  );
  bool _busy = false;

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// 自分で作った予定だけ（Google から読み込んだものは入れない）
  Future<List<CalendarEvent>> _ownEvents() async {
    final all = await _repository.watchAll().first;
    return [
      for (final e in all)
        if (!isGoogleEvent(e)) e,
    ];
  }

  Future<String> _buildText() async {
    final timeZone = SettingsScope.of(context).timeZone;
    final events = await _ownEvents();
    return buildIcs([
      for (final e in events) icsFromEvent(e),
    ], timeZone: timeZone);
  }

  // ───────── 書き出し ─────────

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final text = await _buildText();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(text), mimeType: 'text/calendar')],
          fileNameOverrides: const ['tsuzuri.ics'],
          subject: 'つづりの予定',
          title: 'つづりの予定を書き出す',
        ),
      );
    } catch (e) {
      _say('書き出せませんでした：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    setState(() => _busy = true);
    try {
      final text = await _buildText();
      await Clipboard.setData(ClipboardData(text: text));
      _say('.ics の中身をコピーしました');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ───────── 読み込み ─────────

  Future<void> _import() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['ics'],
    );
    if (file == null) return; // やめた

    setState(() => _busy = true);
    try {
      var text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      if (text.startsWith('﻿')) text = text.substring(1);

      final incoming = parseIcs(text);
      if (incoming.isEmpty) {
        _say('予定が見つかりませんでした');
        return;
      }
      final added = newEventsOnly(incoming, await _ownEvents());
      final skipped = incoming.length - added.length;
      if (!mounted) return;

      if (added.isEmpty) {
        _say('どれもすでに入っている予定でした');
        return;
      }

      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${added.length}件の予定を追加しますか？'),
          content: Text(
            [
              '「${file.name}」から読み込みます。',
              if (skipped > 0) '同じ予定が$skipped件あったので、それは入れません。',
              'カテゴリは「その他」になります。',
            ].join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('追加'),
            ),
          ],
        ),
      );
      if (ok != true) return;

      for (final e in added) {
        await _repository.save(e);
      }
      _say('${added.length}件の予定を追加しました');
    } catch (e) {
      _say('読み込めませんでした：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Scaffold(
      appBar: AppBar(title: const Text('インポート／エクスポート')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (_busy) const LinearProgressIndicator(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('インポート'),
              ),
              ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('.ics ファイルから予定を読み込む'),
                subtitle: const Text('ほかのカレンダーから書き出したファイル'),
                onTap: _import,
              ),
              const Divider(height: 24),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('エクスポート'),
              ),
              ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.ios_share),
                title: const Text('予定を .ics で書き出す'),
                subtitle: const Text('保存したり、ほかのアプリに送ったりできます'),
                onTap: _export,
              ),
              ListTile(
                enabled: !_busy,
                leading: const Icon(Icons.content_copy),
                title: const Text('.ics の中身をコピーする'),
                subtitle: const Text('ファイルで送れないときに'),
                onTap: _copy,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  '書き出すのは、つづりで作った予定だけです。'
                  'Google カレンダーから読み込んだ予定・時間割・テストは入りません。',
                  style: TextStyle(color: outline, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
