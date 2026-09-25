/// 現在地の取得（現在地の天気のために使う。GPS権限が必要）
library;

import 'package:geolocator/geolocator.dart';

enum LocationFailure {
  /// 端末の位置情報サービス（GPS）自体がオフ
  serviceDisabled,

  /// 権限を拒否された
  permissionDenied,

  /// 「今後表示しない」で拒否された（設定アプリから許可し直す必要がある）
  permissionDeniedForever,

  /// そのほかの理由（電波が悪い、タイムアウトなど）
  other,
}

class LocationResult {
  const LocationResult._({this.point, this.failure});

  factory LocationResult.ok(double lat, double lng) =>
      LocationResult._(point: (lat, lng));

  factory LocationResult.fail(LocationFailure f) =>
      LocationResult._(failure: f);

  final (double lat, double lng)? point;
  final LocationFailure? failure;

  bool get isOk => point != null;
}

class CurrentLocationService {
  CurrentLocationService._();

  /// 現在地を取得する（権限がなければ、その場でダイアログを出して聞く）
  static Future<LocationResult> getCurrent() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationResult.fail(LocationFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationResult.fail(LocationFailure.permissionDeniedForever);
      }
      if (permission == LocationPermission.denied) {
        return LocationResult.fail(LocationFailure.permissionDenied);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationResult.ok(pos.latitude, pos.longitude);
    } catch (_) {
      return LocationResult.fail(LocationFailure.other);
    }
  }

  static String messageFor(LocationFailure f) => switch (f) {
    LocationFailure.serviceDisabled => '端末の位置情報サービスがオフになっています。設定でオンにしてください。',
    LocationFailure.permissionDenied => '位置情報の権限が許可されませんでした。',
    LocationFailure.permissionDeniedForever =>
      '位置情報の権限が拒否されています。端末の設定アプリから「つづり」の位置情報を許可してください。',
    LocationFailure.other => '現在地を取得できませんでした。電波の良い場所で試してください。',
  };
}
