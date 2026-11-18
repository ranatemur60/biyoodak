import 'dart:math' as math;

import '../models.dart';
import 'dsp.dart';
import 'perclos.dart';
import 'rppg.dart';

/// Ölçüm sırasında toplanan ham veriler.
class SessionData {
  final DateTime start;
  final double durationMs;
  String lightCondition;
  // Renk örnekleri (her kamera karesi)
  List<double> colorT = [];
  List<double> green = [];
  List<double> luma = [];
  List<bool> pulseFace = []; // nabız ölçümü sırasında yüz görünürlüğü
  // Yüz yer işareti örnekleri
  List<double> lmT = [];
  List<double?> ear = [];
  List<bool> face = [];
  List<bool> offFocus = [];
  double eyeDurationMs = 0;
  // Tepki (Go/No-Go)
  List<double?> reactionMs = []; // null = kaçırıldı
  int falseStarts = 0; // erken dokunuş + mor kareye dokunma
  int nogoTotal = 0;
  int nogoErrors = 0;
  double? notifReactionMs;
  bool notifShown = false;

  // Hangi modüller bu oturumda tamamlandı
  bool pulseDone = false;
  bool eyeDone = false;
  bool reactionDone = false;

  SessionData(
      {required this.start,
      required this.durationMs,
      required this.lightCondition});

  /// Ayrı yapılan bir ölçümün sonuçlarını bu oturum karnesine ekler.
  void mergeFrom(SessionData o) {
    if (o.pulseDone) {
      colorT = o.colorT;
      green = o.green;
      luma = o.luma;
      pulseFace = o.face;
      pulseDone = true;
    }
    if (o.eyeDone || (!eyeDone && o.lmT.isNotEmpty)) {
      lmT = o.lmT;
      ear = o.ear;
      face = o.face;
      offFocus = o.offFocus;
      eyeDurationMs = o.durationMs;
      if (o.eyeDone) eyeDone = true;
    }
    if (o.reactionDone) {
      reactionMs = o.reactionMs;
      falseStarts = o.falseStarts;
      nogoTotal = o.nogoTotal;
      nogoErrors = o.nogoErrors;
      notifReactionMs = o.notifReactionMs;
      notifShown = o.notifShown;
      reactionDone = true;
    }
    lightCondition = o.lightCondition;
  }
}

/// Kişisel kalibrasyon için önceki ölçümlerden temel değerler.
class UserBaseline {
  final double? reactionMs;
  final double? bpm;
  const UserBaseline({this.reactionMs, this.bpm});

  static UserBaseline fromHistory(List<Measurement> h) {
    final rts = h
        .where((m) => m.reactionMedianMs != null)
        .map((m) => m.reactionMedianMs!)
        .toList();
    final hrs = h
        .where((m) => m.bpm != null && m.pulseQ >= 40)
        .map((m) => m.bpm!)
        .toList();
    return UserBaseline(
      reactionMs: rts.length >= 3 ? percentile(rts, 25) : null,
      bpm: hrs.length >= 3 ? median(hrs) : null,
    );
  }
}

double _lin(double x, double x0, double y0, double x1, double y1) {
  if (x <= x0) return y0;
  if (x >= x1) return y1;
  return y0 + (y1 - y0) * (x - x0) / (x1 - x0);
}

/// Göz puanı: PERCLOS ≤%4 → 100, %15 → 50, %30 → 0.
double eyeScoreFrom(EyeResult e) {
  var s = e.perclos <= 15
      ? _lin(e.perclos, 4, 100, 15, 50)
      : _lin(e.perclos, 15, 50, 30, 0);
  if (e.blinkRatePerMin > 35) s -= 10;
  return s.clamp(0, 100).toDouble();
}

/// Tahmini melatonin oranı: M = M_bazal · e^(−k·L·t)
/// k: bireysel ışık hassasiyet katsayısı (varsayılan 0.006 1/(lüks·saat)),
/// L: göz hizasındaki ekran ışığı (gece tipik ~40 lüks), t: saat.
/// Teorik bir modeldir; melatonin doğrudan ölçülmez.
double melatoninRatio(double nightMinutes,
    {double k = 0.006, double lux = 40}) {
  final t = nightMinutes / 60.0;
  return math.exp(-k * lux * t);
}

String exposureLabel(double score) =>
    score < 33 ? 'DÜŞÜK' : (score < 66 ? 'ORTA' : 'YÜKSEK');

/// Ham verilerden tüm sonuçları hesaplar.
Measurement computeMeasurement(SessionData d,
    {required UserBaseline baseline,
    required int subjectiveFatigue,
    required double nightScreenMin}) {
  // --- Göz (PERCLOS) ---
  final eye = d.eyeDone
      ? analyzeEyes(d.lmT, d.ear,
          durationMs: d.eyeDurationMs > 0 ? d.eyeDurationMs : d.durationMs)
      : EyeResult.empty;
  final eyeScore = d.eyeDone ? eyeScoreFrom(eye) : 0.0;

  // --- Nabız (rPPG) ---
  final r = d.pulseDone ? analyzeRppg(d.colorT, d.green) : RppgResult.empty;
  final pf = d.pulseFace.isNotEmpty ? d.pulseFace : d.face;
  final pulseFaceRatio =
      pf.isEmpty ? 0.0 : pf.where((f) => f).length / pf.length;
  final faceRatio = d.face.isEmpty
      ? 0.0
      : d.face.where((f) => f).length / d.face.length;
  final pulseQ = r.quality * pulseFaceRatio;
  double? pulseScore;
  var stress = 'Ölçülemedi';
  if (r.bpm != null && pulseQ >= 20) {
    final base = baseline.bpm ?? 75;
    final dev = r.bpm! - base;
    var s = _lin(dev, 5, 100, 30, 40);
    if (r.bpm! > 110) s -= 15;
    if (r.rmssd != null && r.rmssd! < 20) s -= 10;
    pulseScore = s.clamp(0, 100).toDouble();
    stress = dev > 20 || r.bpm! > 105
        ? 'Yüksek'
        : (dev > 8 ? 'Orta' : 'Düşük');
  }

  // --- Tepki ---
  final answered = d.reactionMs.whereType<double>().toList();
  final misses = d.reactionMs.where((v) => v == null).length;
  final slow = answered.where((v) => v > 500).length;
  final lapses = misses + slow;
  double? rtMed, rtMean;
  var reactionScore = 0.0;
  if (answered.isNotEmpty) {
    rtMed = median(answered);
    rtMean = mean(answered);
    var s = rtMed <= 500
        ? _lin(rtMed, 280, 100, 500, 50)
        : _lin(rtMed, 500, 50, 800, 0);
    s -= 10 * lapses + math.min(20, 3 * d.falseStarts);
    if (baseline.reactionMs != null) {
      final ratio = rtMed / baseline.reactionMs!;
      if (ratio > 1.1) s -= math.min(25, (ratio - 1.1) * 100);
    }
    if (d.notifReactionMs != null) {
      s -= _lin(d.notifReactionMs!, 900, 0, 2500, 15);
    } else if (d.notifShown) {
      s -= 10; // bildirim kaçırıldı
    }
    reactionScore = s.clamp(0, 100).toDouble();
  }
  final reactionQ = d.reactionMs.isEmpty
      ? 0.0
      : 100.0 * answered.length / d.reactionMs.length;
  if (!d.reactionDone) reactionScore = 0;

  // --- Odak (bakış kayması) ---
  final offPct = d.offFocus.isEmpty
      ? 100.0
      : 100.0 * d.offFocus.where((o) => o).length / d.offFocus.length;
  final focusScore = (100 - offPct * 1.5).clamp(0, 100).toDouble();
  final focusQ = 100 * faceRatio;

  // --- Bileşik gösterge (3 ölçüm kaynağı) ---
  // Göz %40, Tepki (reaksiyon %70 + odak %30) %40, Nabız %20
  // Yalnızca tamamlanan modüller ağırlıklandırılır.
  final hasFocus = d.offFocus.isNotEmpty;
  var wSum = 0.0, sum = 0.0;
  void add(double w, double v) {
    wSum += w;
    sum += w * v;
  }

  if (d.eyeDone) add(0.4, eyeScore);
  if (d.reactionDone) add(0.28, reactionScore);
  if (hasFocus) add(0.12, focusScore);
  if (pulseScore != null) add(0.2, pulseScore);
  final composite = wSum > 0 ? sum / wSum : 0.0;

  final qs = <double>[
    if (d.eyeDone) eye.quality,
    if (d.pulseDone) pulseQ,
    if (d.reactionDone) reactionQ,
    if (hasFocus) focusQ,
  ];
  final confidence = qs.isEmpty ? 0.0 : qs.reduce((a, b) => a + b) / qs.length;

  final mel = melatoninRatio(nightScreenMin);
  final exposure = ((1 - mel) * 100).clamp(0, 100).toDouble();

  return Measurement(
    time: d.start,
    lightCondition: d.lightCondition,
    durationS: d.durationMs / 1000,
    perclos: eye.perclos,
    blinks: eye.blinks,
    blinkRate: eye.blinkRatePerMin,
    openEar: eye.openEar,
    bpm: pulseScore != null ? r.bpm : null,
    snrDb: r.snrDb,
    rmssd: r.rmssd,
    stress: stress,
    cameraFps: r.sampleRate,
    reactionMedianMs: rtMed,
    reactionMeanMs: rtMean,
    stimuli: d.reactionMs.length,
    answered: answered.length,
    lapses: lapses,
    falseStarts: d.falseStarts,
    notifReactionMs: d.notifReactionMs,
    offFocusPct: hasFocus ? offPct : 0,
    subjectiveFatigue: subjectiveFatigue,
    nightScreenMin: nightScreenMin,
    melatoninRatio: mel,
    circadianExposure: exposure,
    faceBrightness: d.luma.isEmpty ? 0 : mean(d.luma),
    eyeScore: eyeScore,
    pulseScore: pulseScore,
    reactionScore: reactionScore,
    focusScore: hasFocus ? focusScore : 0,
    composite: composite.clamp(0, 100).toDouble(),
    pulseDone: d.pulseDone,
    eyeDone: d.eyeDone,
    reactionDone: d.reactionDone,
    nogoTotal: d.nogoTotal,
    nogoErrors: d.nogoErrors,
    eyeQ: eye.quality,
    pulseQ: pulseQ,
    reactionQ: reactionQ,
    focusQ: hasFocus ? focusQ : 0,
    confidence: confidence,
    earSeries: eye.earSeries,
    ppgSignal: r.signal,
    spectrumFreqs: downsample(r.spectrumFreqs, 140),
    spectrum: downsample(r.spectrum, 140),
  );
}

/// Gösterge seviyeleri (rapordaki eşikler).
enum FocusLevel { high, mild, severe }

FocusLevel levelOf(double score) => score >= 80
    ? FocusLevel.high
    : (score >= 50 ? FocusLevel.mild : FocusLevel.severe);

String levelTitle(FocusLevel l) => switch (l) {
      FocusLevel.high => 'Yüksek Odak',
      FocusLevel.mild => 'Hafif Yorgunluk',
      FocusLevel.severe => 'Yüksek Bilişsel Yorgunluk',
    };
