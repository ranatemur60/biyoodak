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

  // HRV (RMSSD): yalnızca sinyal çok temizse
  double? rmssd;
  if (bpm != null && snr > 0 && durS >= 30) {
    final minDist = (fs * 60 / (bpm * 1.4)).floor();
    final peaks = findPeaks(y, math.max(minDist, 5));
    final expected = 60000 / bpm;
    final ibis = <double>[];
    for (var i = 1; i < peaks.length; i++) {
      final ibi = (peaks[i] - peaks[i - 1]) * 1000 / fs;
      if ((ibi - expected).abs() < expected * 0.25) ibis.add(ibi);
    }
    if (ibis.length >= 20) {
      var s = 0.0;
      for (var i = 1; i < ibis.length; i++) {
        s += math.pow(ibis[i] - ibis[i - 1], 2);
      }
      rmssd = math.sqrt(s / (ibis.length - 1));
    }
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
