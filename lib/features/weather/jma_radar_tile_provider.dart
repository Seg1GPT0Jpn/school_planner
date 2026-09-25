/// 気象庁の降水ナウキャストのタイル画像を、Google マップの上に重ねて表示するための
/// TileProvider
library;

import 'dart:typed_data';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'jma_radar_times.dart';

class JmaRadarTileProvider implements TileProvider {
  /// 表示するコマ（時刻）。切りかえるときはマップ側の clearTileCache と合わせて使う。
  RadarFrame? frame;

  static const _timeout = Duration(seconds: 8);

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    final f = frame;
    // 気象庁のタイルは z=4〜10 の範囲だけ用意されている
    if (f == null || zoom == null || zoom < 4 || zoom > 10) {
      return TileProvider.noTile;
    }
    try {
      final uri = Uri.parse('${f.tileUrlTemplate}/$zoom/$x/$y.png');
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        return TileProvider.noTile;
      }
      final Uint8List bytes = res.bodyBytes;
      return Tile(256, 256, bytes);
    } catch (_) {
      return TileProvider.noTile;
    }
  }
}
