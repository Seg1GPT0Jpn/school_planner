/// シンプルなFFT（基数2、反復版）と、スペクトラム表示用のデータ作り
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// n（2の累乗）ぶんの実数信号 [re] をその場でFFTする。[im] は0で初期化して渡す。
/// 結果は re/im に上書きされる（複素スペクトラム）。
void fft(Float64List re, Float64List im) {
  final n = re.length;
  if (n <= 1) return;
  // ビット反転並べ替え
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; (j & bit) != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
  for (var len = 2; len <= n; len <<= 1) {
    final ang = -2 * math.pi / len;
    final wRe = math.cos(ang);
    final wIm = math.sin(ang);
    for (var i = 0; i < n; i += len) {
      var curRe = 1.0, curIm = 0.0;
      for (var k = 0; k < len ~/ 2; k++) {
        final uRe = re[i + k];
        final uIm = im[i + k];
        final vRe = re[i + k + len ~/ 2] * curRe - im[i + k + len ~/ 2] * curIm;
        final vIm = re[i + k + len ~/ 2] * curIm + im[i + k + len ~/ 2] * curRe;
        re[i + k] = uRe + vRe;
        im[i + k] = uIm + vIm;
        re[i + k + len ~/ 2] = uRe - vRe;
        im[i + k + len ~/ 2] = uIm - vIm;
        final nextRe = curRe * wRe - curIm * wIm;
        final nextIm = curRe * wIm + curIm * wRe;
        curRe = nextRe;
        curIm = nextIm;
      }
    }
  }
}

/// PCM16のバイト列から、窓関数（ハン窓）をかけたうえでの振幅スペクトラムを作る。
/// 戻り値は、インデックス k が周波数 k*sampleRate/n の振幅（正規化前の目安値）。
List<double> magnitudeSpectrum(Uint8List pcm16LEBytes, {int fftSize = 4096}) {
  final n = fftSize;
  final re = Float64List(n);
  final im = Float64List(n);
  final bd = ByteData.sublistView(pcm16LEBytes);
  final available = pcm16LEBytes.length ~/ 2;
  for (var i = 0; i < n; i++) {
    if (i >= available) break;
    final v = bd.getInt16(i * 2, Endian.little) / 32768.0;
    final window = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)); // ハン窓
    re[i] = v * window;
  }
  fft(re, im);
  return [for (var i = 0; i < n ~/ 2; i++) math.sqrt(re[i] * re[i] + im[i] * im[i])];
}
