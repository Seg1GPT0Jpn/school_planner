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
    final headers = {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
    };
    final res = switch (method) {
      'GET' => await http.get(uri, headers: headers),
      'POST' => await http.post(uri, headers: headers, body: jsonEncode(body)),
      'PUT' => await http.put(uri, headers: headers, body: jsonEncode(body)),
      'DELETE' => await http.delete(uri, headers: headers),
      _ => throw ArgumentError(method),
    };
    if (res.statusCode == 401) {
      _token = null;
      throw Exception('許可が切れました。もう一度「接続」してください');
    }
    if (res.statusCode >= 300) {
      throw Exception('Google カレンダーのエラー（${res.statusCode}）：${res.body}');
    }
    return res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;
  }

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
        '/calendars/${Uri.encodeComponent(calendarId)}/events',
        query: {
          'timeMin': from.toUtc().toIso8601String(),
          'timeMax': to.toUtc().toIso8601String(),
          'singleEvents': 'true',
          'orderBy': 'startTime',
          'maxResults': '2500',
          if (page != null) 'pageToken': page,
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
