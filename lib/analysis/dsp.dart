import 'dart:math' as math;

/// Basit sayısal sinyal işleme yardımcıları (harici kütüphane gerektirmez).

/// Düzensiz zaman damgalı örnekleri sabit örnekleme hızına doğrusal
/// interpolasyonla yeniden örnekler.
List<double> resampleUniform(List<double> tMs, List<double> v, double fs) {
  if (tMs.length < 2) return List<double>.from(v);
  final t0 = tMs.first;
  final t1 = tMs.last;
  final n = ((t1 - t0) / 1000.0 * fs).floor();
  final out = List<double>.filled(math.max(n, 0), 0);
  var j = 0;
  for (var i = 0; i < n; i++) {
    final t = t0 + i * 1000.0 / fs;
    while (j < tMs.length - 2 && tMs[j + 1] < t) {
      j++;
    }
    final ta = tMs[j], tb = tMs[j + 1];
    final a = v[j], b = v[j + 1];
    final w = tb == ta ? 0.0 : ((t - ta) / (tb - ta)).clamp(0.0, 1.0);
    out[i] = a + (b - a) * w;
  }
  return out;
}

double mean(List<double> x) =>
    x.isEmpty ? 0 : x.reduce((a, b) => a + b) / x.length;

double stdDev(List<double> x) {
  if (x.length < 2) return 0;
  final m = mean(x);
  var s = 0.0;
  for (final v in x) {
    s += (v - m) * (v - m);
  }
  return math.sqrt(s / (x.length - 1));
}

double median(List<double> x) {
  if (x.isEmpty) return double.nan;
  final s = List<double>.from(x)..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

double percentile(List<double> x, double p) {
  if (x.isEmpty) return double.nan;
  final s = List<double>.from(x)..sort();
  final idx = (p / 100 * (s.length - 1)).clamp(0, s.length - 1).toDouble();
  final lo = idx.floor(), hi = idx.ceil();
  return s[lo] + (s[hi] - s[lo]) * (idx - lo);
}

/// Hareketli ortalama çıkararak yavaş aydınlatma değişimlerini (trend) giderir.
List<double> detrendMovingAverage(List<double> x, int win) {
  final n = x.length;
  final out = List<double>.filled(n, 0);
  final half = win ~/ 2;
  final prefix = List<double>.filled(n + 1, 0);
  for (var i = 0; i < n; i++) {
    prefix[i + 1] = prefix[i] + x[i];
  }
  for (var i = 0; i < n; i++) {
    final a = math.max(0, i - half);
    final b = math.min(n, i + half + 1);
    out[i] = x[i] - (prefix[b] - prefix[a]) / (b - a);
  }
  return out;
}

/// İkinci dereceden (biquad) filtre katsayıları (RBJ tasarımı).
class Biquad {
  final double b0, b1, b2, a1, a2;
  const Biquad(this.b0, this.b1, this.b2, this.a1, this.a2);

  factory Biquad.highPass(double fc, double fs, [double q = 0.7071]) {
    final w0 = 2 * math.pi * fc / fs;
    final alpha = math.sin(w0) / (2 * q);
    final cosw = math.cos(w0);
    final a0 = 1 + alpha;
    return Biquad((1 + cosw) / 2 / a0, -(1 + cosw) / a0, (1 + cosw) / 2 / a0,
        -2 * cosw / a0, (1 - alpha) / a0);
  }

  factory Biquad.lowPass(double fc, double fs, [double q = 0.7071]) {
    final w0 = 2 * math.pi * fc / fs;
    final alpha = math.sin(w0) / (2 * q);
    final cosw = math.cos(w0);
    final a0 = 1 + alpha;
    return Biquad((1 - cosw) / 2 / a0, (1 - cosw) / a0, (1 - cosw) / 2 / a0,
        -2 * cosw / a0, (1 - alpha) / a0);
  }

  List<double> apply(List<double> x) {
    final y = List<double>.filled(x.length, 0);
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    for (var i = 0; i < x.length; i++) {
      final x0 = x[i];
      final y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      y[i] = y0;
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }
    return y;
  }
}

/// Faz kaymasız (ileri-geri) Butterworth bant geçiren filtre.
List<double> bandPass(List<double> x, double lowHz, double highHz, double fs) {
  if (x.length < 8) return List<double>.from(x);
  final filters = [
    Biquad.highPass(lowHz, fs),
    Biquad.highPass(lowHz, fs),
    Biquad.lowPass(highHz, fs),
    Biquad.lowPass(highHz, fs),
  ];
  var y = List<double>.from(x);
  for (final f in filters) {
    y = f.apply(y);
  }
  y = y.reversed.toList();
  for (final f in filters) {
    y = f.apply(y);
  }
  return y.reversed.toList();
}

/// Hann pencereli doğrudan Fourier dönüşümü ile verilen frekanslardaki
/// spektral gücü hesaplar.
List<double> powerSpectrum(List<double> x, double fs, List<double> freqs) {
  final n = x.length;
  final w = List<double>.generate(
      n, (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / math.max(n - 1, 1)));
  final out = List<double>.filled(freqs.length, 0);
  for (var k = 0; k < freqs.length; k++) {
    final om = 2 * math.pi * freqs[k] / fs;
    var re = 0.0, im = 0.0;
    // Döner fazör ile hızlı hesap
    final cosStep = math.cos(om), sinStep = math.sin(om);
    var c = 1.0, s = 0.0;
    for (var i = 0; i < n; i++) {
      final v = x[i] * w[i];
      re += v * c;
      im -= v * s;
      final nc = c * cosStep - s * sinStep;
      s = s * cosStep + c * sinStep;
      c = nc;
    }
    out[k] = (re * re + im * im) / n;
  }
  return out;
}

/// Basit tepe bulma (en az [minDist] örnek aralıklı yerel maksimumlar).
List<int> findPeaks(List<double> x, int minDist) {
  final peaks = <int>[];
  for (var i = 1; i < x.length - 1; i++) {
    if (x[i] > x[i - 1] && x[i] >= x[i + 1] && x[i] > 0) {
      if (peaks.isNotEmpty && i - peaks.last < minDist) {
        if (x[i] > x[peaks.last]) peaks[peaks.length - 1] = i;
      } else {
        peaks.add(i);
      }
    }
  }
  return peaks;
}

/// Listeyi en fazla [maxPoints] noktaya indirger (grafikler için).
List<double> downsample(List<double> x, int maxPoints) {
  if (x.length <= maxPoints) return List<double>.from(x);
  final step = x.length / maxPoints;
  return List<double>.generate(maxPoints, (i) => x[(i * step).floor()]);
}
