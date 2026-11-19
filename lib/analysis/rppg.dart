import 'dart:math' as math;

import 'dsp.dart';

/// rPPG (uzaktan fotopletismografi) analiz sonucu.
class RppgResult {
  final double? bpm; // Tahmini kalp atım hızı
  final double snrDb; // Sinyal-gürültü oranı (dB)
  final double? rmssd; // HRV (ms), güvenilir değilse null
  final double quality; // 0-100
  final double sampleRate; // Kamera örnekleme hızı (fps)
  final List<double> signal; // Filtrelenmiş sinyal (grafik için)
  final List<double> spectrumFreqs;
  final List<double> spectrum;

  const RppgResult({
    required this.bpm,
    required this.snrDb,
    required this.rmssd,
    required this.quality,
    required this.sampleRate,
    required this.signal,
    required this.spectrumFreqs,
    required this.spectrum,
  });

  static const empty = RppgResult(
      bpm: null,
      snrDb: -20,
      rmssd: null,
      quality: 0,
      sampleRate: 0,
      signal: [],
      spectrumFreqs: [],
      spectrum: []);
}

/// Alın bölgesinden alınan ortalama yeşil kanal değerlerinden (C(t)) nabız
/// tahmini yapar.
///
/// Adımlar: 30 Hz'e yeniden örnekleme → trend giderme → normalizasyon →
/// 0.7-3.5 Hz bant geçiren filtre → Hann pencereli Fourier güç spektrumu →
/// baskın tepe → BPM. SNR, de Haan & Jeanne (2013) tanımına göre hesaplanır.
RppgResult analyzeRppg(List<double> tMs, List<double> green,
    {double lowHz = 0.7, double highHz = 3.5}) {
  if (tMs.length < 60) return RppgResult.empty;
  final durS = (tMs.last - tMs.first) / 1000.0;
  if (durS < 8) return RppgResult.empty;
  final rawFs = (tMs.length - 1) / durS;
  const fs = 30.0;
  var x = resampleUniform(tMs, green, fs);
  x = detrendMovingAverage(x, (fs * 1.5).round());
  final sd = stdDev(x);
  if (sd == 0) return RppgResult.empty;
  // Ani hareket kaynaklı aşırı değerleri kırp (±3 SD)
  x = x.map((v) => (v / sd).clamp(-3.0, 3.0)).toList();
  // Başlangıçtaki filtre geçici etkisini at
  var y = bandPass(x, lowHz, highHz, fs);
  final skip = math.min((fs * 1).round(), y.length ~/ 4);
  y = y.sublist(skip, y.length - skip);

  final freqs = <double>[];
  for (var f = lowHz; f <= highHz + 1e-9; f += 0.01) {
    freqs.add(double.parse(f.toStringAsFixed(2)));
  }
  final p = powerSpectrum(y, fs, freqs);
  var kMax = 0;
  for (var k = 1; k < p.length; k++) {
    if (p[k] > p[kMax]) kMax = k;
  }
  final f0 = freqs[kMax];

  // SNR: temel frekans (±0.1 Hz) ve 1. harmonik (±0.2 Hz) içindeki güç / geri kalan
  var sig = 0.0, noise = 0.0;
  for (var k = 0; k < p.length; k++) {
    final f = freqs[k];
    if ((f - f0).abs() <= 0.1 || (f - 2 * f0).abs() <= 0.2) {
      sig += p[k];
    } else {
      noise += p[k];
    }
  }
  final snr = 10 * math.log(sig / math.max(noise, 1e-12)) / math.ln10;

  // Kalite: SNR ve kamera hızı
  final snrQ = ((snr + 9) / 12).clamp(0.0, 1.0);
  final fpsQ = (rawFs / 15).clamp(0.0, 1.0);
  final quality = 100 * snrQ * fpsQ;
  final bpm = snr > -9 ? f0 * 60 : null;

  // HRV (RMSSD): nabız frekansı çevresinde dar bantlı sinyalde tepe noktaları
  // bulunur, tepe zamanları parabolik interpolasyonla 33 ms'lik kare
  // aralığından daha hassas hesaplanır. Hatalı atımlar ayıklanır.
  double? rmssd;
  if (bpm != null && snr > -3 && durS >= 25) {
    final lo = math.max(lowHz, f0 - 0.6), hi = math.min(highHz, f0 + 0.9);
    var z = bandPass(x, lo, hi, fs);
    z = z.sublist(skip, z.length - skip);
    final minDist = (fs * 60 / (bpm * 1.35)).floor();
    final peaks = findPeaks(z, math.max(minDist, 5));
    final tPeak = <double>[];
    for (final k in peaks) {
      var off = 0.0;
      if (k > 0 && k < z.length - 1) {
        final a = z[k - 1], b = z[k], c = z[k + 1];
        final den = a - 2 * b + c;
        if (den.abs() > 1e-12) off = (0.5 * (a - c) / den).clamp(-0.5, 0.5);
      }
      tPeak.add((k + off) * 1000 / fs);
    }
    final expected = 60000 / bpm;
    final ibis = <double?>[];
    for (var i = 1; i < tPeak.length; i++) {
      final ibi = tPeak[i] - tPeak[i - 1];
      ibis.add((ibi - expected).abs() < expected * 0.3 ? ibi : null);
    }
    var s = 0.0, n = 0, valid = 0;
    for (var i = 0; i < ibis.length; i++) {
      if (ibis[i] != null) valid++;
      if (i == 0 || ibis[i] == null || ibis[i - 1] == null) continue;
      final d = ibis[i]! - ibis[i - 1]!;
      if (d.abs() > 250) continue; // artefakt
      s += d * d;
      n++;
    }
    if (valid >= 15 && n >= 10) rmssd = math.sqrt(s / n);
  }

  return RppgResult(
    bpm: bpm,
    snrDb: snr,
    rmssd: rmssd,
    quality: quality,
    sampleRate: rawFs,
    signal: downsample(y, 400),
    spectrumFreqs: freqs,
    spectrum: p,
  );
}
