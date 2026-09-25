/// Google カレンダーとのやりとり
library;

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GoogleCalendarInfo {
  const GoogleCalendarInfo(this.id, this.name, this.color, this.canWrite);
  final String id;
  final String name;
  final String? color;
  final bool canWrite;
}

/// Google カレンダーから返ってきたエラー
class GoogleApiException implements Exception {
  const GoogleApiException(this.status, this.message);
  final int status;
  final String message;

  /// その予定がもう Google にない
  bool get isGone => status == 404 || status == 410;

  @override
  String toString() => message;
}

class GoogleCalendarService {
  GoogleCalendarService._();
  static final GoogleCalendarService instance = GoogleCalendarService._();

  static const _scope = 'https://www.googleapis.com/auth/calendar';
  static const _base = 'https://www.googleapis.com/calendar/v3';

  String? _token;
  DateTime? _expires;

  /// 許可がまだ有効か
  bool get isConnected =>
      _token != null && _expires != null && DateTime.now().isBefore(_expires!);

  /// 許可をもらう（ボタンを押したときに呼ぶ）
  Future<void> connect() async {
    final user = FirebaseAuth.instance.currentUser!;
    final provider = GoogleAuthProvider()
      ..addScope(_scope)
      ..setCustomParameters({'login_hint': user.email ?? ''});
    final result = kIsWeb
        ? await user.reauthenticateWithPopup(provider)
        : await user.reauthenticateWithProvider(provider);
    final token = result.credential?.accessToken;
    if (token == null) throw Exception('Google から許可をもらえませんでした');
    _token = token;
    _expires = DateTime.now().add(const Duration(minutes: 55));
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (!isConnected) await connect();
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);

    // 「短い時間に送りすぎ」と言われたら、少し待ってやり直す（最大5回）
    for (var attempt = 0; ; attempt++) {
      final headers = {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };
      final res = switch (method) {
        'GET' => await http.get(uri, headers: headers),
        'POST' => await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        'PUT' => await http.put(uri, headers: headers, body: jsonEncode(body)),
        'PATCH' => await http.patch(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        'DELETE' => await http.delete(uri, headers: headers),
        _ => throw ArgumentError(method),
      };
      final text = res.body;

      final tooMany =
          res.statusCode == 429 ||
          (res.statusCode == 403 && text.contains('ateLimitExceeded'));
      if (tooMany && attempt < 5) {
        await Future<void>.delayed(
          Duration(milliseconds: 1000 * (1 << attempt)),
        );
        continue;
      }
      if (res.statusCode == 401) {
        _token = null;
        throw const GoogleApiException(401, '許可が切れました。もう一度「接続」してください');
      }
      if (tooMany) {
        throw const GoogleApiException(
          429,
          '短い時間に送りすぎました。1分ほど待ってからもう一度🔄してください',
        );
      }
      if (res.statusCode == 403 &&
          (text.contains('insufficientPermissions') ||
              text.contains('SCOPE_INSUFFICIENT'))) {
        _token = null;
        throw const GoogleApiException(
          403,
          '書き込みの許可がありません。⚙→「Googleカレンダー」で接続し直し、「カレンダーの表示・編集」を許可してください',
        );
      }
      if (res.statusCode == 403) {
        throw GoogleApiException(403, 'このカレンダーは変更できません（403）：$text');
      }
      if (res.statusCode >= 300) {
        throw GoogleApiException(
          res.statusCode,
          'Google カレンダーのエラー（${res.statusCode}）：$text',
        );
      }
      return text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>;
    }
  }

  String _events(String calendarId) =>
      '/calendars/${Uri.encodeComponent(calendarId)}/events';

  /// 自分のカレンダーの一覧
  Future<List<GoogleCalendarInfo>> listCalendars() async {
    final data = await _call('GET', '/users/me/calendarList');
    return [
      for (final c in (data['items'] as List<dynamic>? ?? const []))
        GoogleCalendarInfo(
          (c as Map)['id'] as String,
          (c['summaryOverride'] ?? c['summary'] ?? '') as String,
          c['backgroundColor'] as String?,
          c['accessRole'] == 'owner' || c['accessRole'] == 'writer',
        ),
    ];
  }

  /// 予定の一覧（繰り返しの予定は1回ずつに分けて取得）
  Future<List<Map<String, dynamic>>> listEvents(
    String calendarId,
    DateTime from,
    DateTime to,
  ) async {
    final items = <Map<String, dynamic>>[];
    String? page;
    do {
      final data = await _call(
        'GET',
        _events(calendarId),
        query: {
          'timeMin': from.toUtc().toIso8601String(),
          'timeMax': to.toUtc().toIso8601String(),
          'singleEvents': 'true',
          'orderBy': 'startTime',
          'maxResults': '2500',
          'pageToken': ?page,
        },
      );
      items.addAll([
        for (final e in (data['items'] as List<dynamic>? ?? const []))
          Map<String, dynamic>.from(e as Map),
      ]);
      page = data['nextPageToken'] as String?;
    } while (page != null);
    return items;
  }

  /// 予定を追加する（Google の予定 ID を返す）
  Future<String> insertEvent(
    String calendarId,
    Map<String, dynamic> body,
  ) async {
    final data = await _call('POST', _events(calendarId), body: body);
    return data['id'] as String;
  }

  /// 予定を丸ごと書き換える
  Future<void> updateEvent(
    String calendarId,
    String eventId,
    Map<String, dynamic> body,
  ) => _call(
    'PUT',
    '${_events(calendarId)}/${Uri.encodeComponent(eventId)}',
    body: body,
  );

  /// 予定の一部だけ書き換える
  Future<void> patchEvent(
    String calendarId,
    String eventId,
    Map<String, dynamic> body,
  ) => _call(
    'PATCH',
    '${_events(calendarId)}/${Uri.encodeComponent(eventId)}',
    body: body,
  );

  /// 予定を消す（もう消えていたら何もしない）
  Future<void> deleteEvent(String calendarId, String eventId) async {
    try {
      await _call(
        'DELETE',
        '${_events(calendarId)}/${Uri.encodeComponent(eventId)}',
      );
    } on GoogleApiException catch (e) {
      if (!e.isGone) rethrow;
    }
  }

  /// 「つづり」カレンダーを作る（ID を返す）
  Future<String> createTsuzuriCalendar() async {
    final data = await _call(
      'POST',
      '/calendars',
      body: {'summary': 'つづり', 'timeZone': 'Asia/Tokyo'},
    );
    return data['id'] as String;
  }
}
