import 'dart:math' as math;

import 'package:biyoodak/analysis/perclos.dart';
import 'package:biyoodak/analysis/rppg.dart';
import 'package:biyoodak/analysis/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rPPG sentetik 72 BPM sinyalini bulur', () {
    final rnd = math.Random(1);
    final t = <double>[];
    final g = <double>[];
    var time = 0.0;
    while (time < 45000) {
      t.add(time);
      final s = 0.6 * math.sin(2 * math.pi * 1.2 * time / 1000) +
          5 * math.sin(2 * math.pi * 0.05 * time / 1000) + // aydınlatma kayması
          rnd.nextDouble() * 1.2 - 0.6;
      g.add(120 + s);
      time += 28 + rnd.nextDouble() * 12; // düzensiz kamera hızı (~30 fps)
    }
    final r = analyzeRppg(t, g);
    expect(r.bpm, isNotNull);
    expect((r.bpm! - 72).abs(), lessThan(2));
    expect(r.snrDb, greaterThan(0));
  });

  test('rPPG değişken atım aralıklarından HRV (RMSSD) hesaplar', () {
    final rnd = math.Random(5);
    // Gerçek atım zamanları: ortalama 833 ms, rastgele değişim
    final beats = <double>[0];
    while (beats.last < 47000) {
      final u = rnd.nextDouble() + rnd.nextDouble() + rnd.nextDouble() - 1.5;
      beats.add(beats.last + 833 + u * 50);
    }
    var ss = 0.0;
    for (var i = 2; i < beats.length; i++) {
      final d = (beats[i] - beats[i - 1]) - (beats[i - 1] - beats[i - 2]);
      ss += d * d;
    }
    final trueRmssd = math.sqrt(ss / (beats.length - 2));
    final t = <double>[];
    final g = <double>[];
    var time = 0.0, k = 0;
    while (time < 45000) {
      while (beats[k + 1] <= time) {
        k++;
      }
      final ph = (time - beats[k]) / (beats[k + 1] - beats[k]);
      t.add(time);
      g.add(120 + 0.6 * math.cos(2 * math.pi * ph) + rnd.nextDouble() * 0.6 - 0.3);
      time += 30 + rnd.nextDouble() * 6;
    }
    final r = analyzeRppg(t, g);
    expect(r.rmssd, isNotNull);
    expect((r.rmssd! - trueRmssd).abs(), lessThan(15),
        reason: 'gerçek ${trueRmssd.toStringAsFixed(1)} ölçülen ${r.rmssd!.toStringAsFixed(1)}');
  });

  test('rPPG saf gürültüde düşük kalite verir', () {
    final rnd = math.Random(2);
    final t = List<double>.generate(1300, (i) => i * 33.3);
    final g = List<double>.generate(1300, (i) => 100 + rnd.nextDouble() * 4);
    final r = analyzeRppg(t, g);
    expect(r.quality, lessThan(60));
  });

  test('PERCLOS ve göz kırpma sayımı', () {
    final t = <double>[];
    final ear = <double?>[];
    for (var i = 0; i < 450; i++) {
      // 10 Hz, 45 sn
      t.add(i * 100.0);
      final closed = i % 50 == 0 || i % 50 == 1; // her 5 sn'de 200 ms kırpma
      ear.add(closed ? 0.08 : 0.30);
    }
    final e = analyzeEyes(t, ear, durationMs: 45000);
    expect(e.blinks, inInclusiveRange(8, 9));
    expect(e.perclos, closeTo(4.0, 0.6));
  });

  test('EAR formülü', () {
    final p = [
      [0.0, 0.0],
      [1.0, 1.0],
      [2.0, 1.0],
      [3.0, 0.0],
      [2.0, -1.0],
      [1.0, -1.0],
    ];
    expect(eyeAspectRatio(p), closeTo(2 / 3, 1e-9));
  });

  test('bileşik puan ve seviyeler', () {
    expect(levelOf(85), FocusLevel.high);
    expect(levelOf(60), FocusLevel.mild);
    expect(levelOf(30), FocusLevel.severe);
    expect(melatoninRatio(0), 1.0);
    expect(melatoninRatio(60), lessThan(1.0));
  });
}
