import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/core/maps.dart';

void main() {
  test('施設名・住所はマップで検索', () {
    final u = mapUri(' 横浜駅 ');
    expect(u.host, 'www.google.com');
    expect(u.path, '/maps/search/');
    expect(u.queryParameters['api'], '1');
    expect(u.queryParameters['query'], '横浜駅');
  });

  test('空ならマップのトップ', () {
    expect(mapUri('').toString(), 'https://www.google.com/maps');
  });

  test('URL はそのまま開く', () {
    expect(
      mapUri('https://maps.app.goo.gl/abc123').toString(),
      'https://maps.app.goo.gl/abc123',
    );
  });
}
