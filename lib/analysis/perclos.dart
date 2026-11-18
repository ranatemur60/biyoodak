import 'dart:math' as math;

import 'dsp.dart';

/// Göz kırpma ve PERCLOS analizi sonucu.
class EyeResult {
  final double perclos; // %
  final int blinks;
  final double blinkRatePerMin;
  final double openEar; // Kişisel kalibre edilmiş açık göz EAR değeri
  final double threshold; // Kapalı göz eşiği
  final double quality; // 0-100
  final List<double> earSeries; // grafik için
  const EyeResult(this.perclos, this.blinks, this.blinkRatePerMin, this.openEar,
      this.threshold, this.quality, this.earSeries);

  static const empty = EyeResult(0, 0, 0, 0, 0, 0, []);
}

/// EAR = (|p2-p6| + |p3-p5|) / (2|p1-p4|)
double eyeAspectRatio(List<List<double>> p) {
  double d(List<double> a, List<double> b) {
    final dx = a[0] - b[0], dy = a[1] - b[1];
    return math.sqrt(dx * dx + dy * dy);
  }

  final h = d(p[0], p[3]);
  if (h == 0) return 0;
  return (d(p[1], p[5]) + d(p[2], p[4])) / (2 * h);
}

/// [tMs]: yer işareti örneklerinin zamanları, [ear]: her örnekteki EAR
/// (yüz yoksa null). Dinamik kalibrasyon: açık göz EAR değeri ölçüm
/// boyunca EAR dağılımının 85. yüzdeliği olarak alınır; kapalı eşik bunun
/// %60'ıdır (P80 ölçütüne yakın).
EyeResult analyzeEyes(List<double> tMs, List<double?> ear,
    {required double durationMs}) {
  final valid = <double>[];
  for (final e in ear) {
    if (e != null && e > 0) valid.add(e);
  }
  if (valid.length < 10 || durationMs <= 0) return EyeResult.empty;
  final openEar = percentile(valid, 85);
  final thr = openEar * 0.6;
  var closedMs = 0.0;
  var validMs = 0.0;
  var blinks = 0;
  var inClosure = false;
  var closureStart = 0.0;
  for (var i = 0; i < tMs.length; i++) {
    final e = ear[i];
    final dt = i + 1 < tMs.length ? (tMs[i + 1] - tMs[i]) : 0.0;
    final cdt = dt.clamp(0.0, 500.0);
    if (e == null || e <= 0) continue;
    validMs += cdt;
    final closed = e < thr;
    if (closed) {
      closedMs += cdt;
      if (!inClosure) {
        inClosure = true;
        closureStart = tMs[i];
      }
    } else if (inClosure) {
      inClosure = false;
      final dur = tMs[i] - closureStart;
      if (dur >= 40 && dur <= 1500) blinks++;
    }
  }
  final perclos = validMs > 0 ? closedMs / validMs * 100 : 0.0;
  final minutes = validMs / 60000;
  final rate = minutes > 0 ? blinks / minutes : 0.0;
  final fps = tMs.length / (durationMs / 1000);
  final coverage = (valid.length / tMs.length).clamp(0.0, 1.0);
  final fpsQ = (fps / 8).clamp(0.0, 1.0);
  return EyeResult(perclos, blinks, rate, openEar, thr,
      100 * coverage * fpsQ, downsample(ear.map((e) => e ?? 0.0).toList(), 300));
}
