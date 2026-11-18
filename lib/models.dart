import 'dart:convert';

/// Kullanıcının ilk açılışta yanıtladığı alışkanlık soruları.
class UserProfile {
  String name;
  int age;
  double weightKg;
  int waterGlasses; // günlük bardak (200 ml)
  double sleepHours;
  String bedTime; // "23:30"
  int nightVideo; // 0: hiç, 1: 1-30, 2: 31-60, 3: 1-2 sa, 4: 2+ sa
  int activity; // 0: az, 1: orta, 2: çok
  int caffeine; // günlük çay/kahve
  bool phoneNearWhileStudy;

  UserProfile({
    this.name = '',
    this.age = 16,
    this.weightKg = 60,
    this.waterGlasses = 5,
    this.sleepHours = 7,
    this.bedTime = '23:30',
    this.nightVideo = 1,
    this.activity = 1,
    this.caffeine = 1,
    this.phoneNearWhileStudy = true,
  });

  /// Gece video süresinin dakika karşılığı (anket kategorisinin orta noktası).
  int get nightVideoMinutes => const [0, 15, 45, 90, 150][nightVideo.clamp(0, 4)];

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'weightKg': weightKg,
        'waterGlasses': waterGlasses,
        'sleepHours': sleepHours,
        'bedTime': bedTime,
        'nightVideo': nightVideo,
        'activity': activity,
        'caffeine': caffeine,
        'phoneNearWhileStudy': phoneNearWhileStudy,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] ?? '',
        age: (j['age'] ?? 16) as int,
        weightKg: (j['weightKg'] ?? 60).toDouble(),
        waterGlasses: (j['waterGlasses'] ?? 5) as int,
        sleepHours: (j['sleepHours'] ?? 7).toDouble(),
        bedTime: j['bedTime'] ?? '23:30',
        nightVideo: (j['nightVideo'] ?? 1) as int,
        activity: (j['activity'] ?? 1) as int,
        caffeine: (j['caffeine'] ?? 1) as int,
        phoneNearWhileStudy: j['phoneNearWhileStudy'] ?? true,
      );
}

/// Bir ölçümün tüm sonuçları.
class Measurement {
  final DateTime time;
  final String lightCondition; // Ek 3: ortam koşulu
  final double durationS;

  // Göz
  final double perclos;
  final int blinks;
  final double blinkRate;
  final double openEar;

  // Nabız
  final double? bpm;
  final double snrDb;
  final double? rmssd;
  final String stress;
  final double cameraFps;

  // Tepki
  final double? reactionMedianMs;
  final double? reactionMeanMs;
  final int stimuli;
  final int answered;
  final int lapses;
  final int falseStarts;
  final double? notifReactionMs;
  final double offFocusPct;

  // Öznel / sirkadiyen
  final int subjectiveFatigue; // 0-10
  final double nightScreenMin;
  final double melatoninRatio; // M_tahmin / M_bazal
  final double circadianExposure; // 0-100
  final double faceBrightness; // 0-255 (ortam ışığı göstergesi)

  // Puanlar
  final double eyeScore;
  final double? pulseScore;
  final double reactionScore;
  final double focusScore;
  final double composite;

  // Kalite (Güven Skoru bileşenleri)
  final double eyeQ;
  final double pulseQ;
  final double reactionQ;
  final double focusQ;
  final double confidence;

  // Grafik verileri (yalnızca son ölçümlerde saklanır)
  final List<double> earSeries;
  final List<double> ppgSignal;
  final List<double> spectrumFreqs;
  final List<double> spectrum;

  Measurement({
    required this.time,
    required this.lightCondition,
    required this.durationS,
    required this.perclos,
    required this.blinks,
    required this.blinkRate,
    required this.openEar,
    required this.bpm,
    required this.snrDb,
    required this.rmssd,
    required this.stress,
    required this.cameraFps,
    required this.reactionMedianMs,
    required this.reactionMeanMs,
    required this.stimuli,
    required this.answered,
    required this.lapses,
    required this.falseStarts,
    required this.notifReactionMs,
    required this.offFocusPct,
    required this.subjectiveFatigue,
    required this.nightScreenMin,
    required this.melatoninRatio,
    required this.circadianExposure,
    required this.faceBrightness,
    required this.eyeScore,
    required this.pulseScore,
    required this.reactionScore,
    required this.focusScore,
    required this.composite,
    required this.eyeQ,
    required this.pulseQ,
    required this.reactionQ,
    required this.focusQ,
    required this.confidence,
    this.earSeries = const [],
    this.ppgSignal = const [],
    this.spectrumFreqs = const [],
    this.spectrum = const [],
  });

  Measurement copyWith({int? subjectiveFatigue, double? composite}) =>
      Measurement.fromJson({
        ...toJson(),
        if (subjectiveFatigue != null) 'subjectiveFatigue': subjectiveFatigue,
        if (composite != null) 'composite': composite,
      });

  Measurement withoutSeries() => Measurement.fromJson(
      {...toJson(), 'earSeries': [], 'ppgSignal': [], 'spectrumFreqs': [], 'spectrum': []});

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'lightCondition': lightCondition,
        'durationS': durationS,
        'perclos': perclos,
        'blinks': blinks,
        'blinkRate': blinkRate,
        'openEar': openEar,
        'bpm': bpm,
        'snrDb': snrDb,
        'rmssd': rmssd,
        'stress': stress,
        'cameraFps': cameraFps,
        'reactionMedianMs': reactionMedianMs,
        'reactionMeanMs': reactionMeanMs,
        'stimuli': stimuli,
        'answered': answered,
        'lapses': lapses,
        'falseStarts': falseStarts,
        'notifReactionMs': notifReactionMs,
        'offFocusPct': offFocusPct,
        'subjectiveFatigue': subjectiveFatigue,
        'nightScreenMin': nightScreenMin,
        'melatoninRatio': melatoninRatio,
        'circadianExposure': circadianExposure,
        'faceBrightness': faceBrightness,
        'eyeScore': eyeScore,
        'pulseScore': pulseScore,
        'reactionScore': reactionScore,
        'focusScore': focusScore,
        'composite': composite,
        'eyeQ': eyeQ,
        'pulseQ': pulseQ,
        'reactionQ': reactionQ,
        'focusQ': focusQ,
        'confidence': confidence,
        'earSeries': earSeries.map(_r3).toList(),
        'ppgSignal': ppgSignal.map(_r3).toList(),
        'spectrumFreqs': spectrumFreqs,
        'spectrum': spectrum.map(_r3).toList(),
      };

  static double _r3(double v) => double.parse(v.toStringAsFixed(3));

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
  static List<double> _l(dynamic v) =>
      v == null ? const [] : (v as List).map((e) => (e as num).toDouble()).toList();

  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
        time: DateTime.parse(j['time']),
        lightCondition: j['lightCondition'] ?? 'Önden yeterli ışık',
        durationS: _d(j['durationS']) ?? 45,
        perclos: _d(j['perclos']) ?? 0,
        blinks: (j['blinks'] ?? 0) as int,
        blinkRate: _d(j['blinkRate']) ?? 0,
        openEar: _d(j['openEar']) ?? 0,
        bpm: _d(j['bpm']),
        snrDb: _d(j['snrDb']) ?? -20,
        rmssd: _d(j['rmssd']),
        stress: j['stress'] ?? '-',
        cameraFps: _d(j['cameraFps']) ?? 0,
        reactionMedianMs: _d(j['reactionMedianMs']),
        reactionMeanMs: _d(j['reactionMeanMs']),
        stimuli: (j['stimuli'] ?? 0) as int,
        answered: (j['answered'] ?? 0) as int,
        lapses: (j['lapses'] ?? 0) as int,
        falseStarts: (j['falseStarts'] ?? 0) as int,
        notifReactionMs: _d(j['notifReactionMs']),
        offFocusPct: _d(j['offFocusPct']) ?? 0,
        subjectiveFatigue: (j['subjectiveFatigue'] ?? 5) as int,
        nightScreenMin: _d(j['nightScreenMin']) ?? 0,
        melatoninRatio: _d(j['melatoninRatio']) ?? 1,
        circadianExposure: _d(j['circadianExposure']) ?? 0,
        faceBrightness: _d(j['faceBrightness']) ?? 0,
        eyeScore: _d(j['eyeScore']) ?? 0,
        pulseScore: _d(j['pulseScore']),
        reactionScore: _d(j['reactionScore']) ?? 0,
        focusScore: _d(j['focusScore']) ?? 0,
        composite: _d(j['composite']) ?? 0,
        eyeQ: _d(j['eyeQ']) ?? 0,
        pulseQ: _d(j['pulseQ']) ?? 0,
        reactionQ: _d(j['reactionQ']) ?? 0,
        focusQ: _d(j['focusQ']) ?? 0,
        confidence: _d(j['confidence']) ?? 0,
        earSeries: _l(j['earSeries']),
        ppgSignal: _l(j['ppgSignal']),
        spectrumFreqs: _l(j['spectrumFreqs']),
        spectrum: _l(j['spectrum']),
      );

  String encode() => jsonEncode(toJson());
  static Measurement decode(String s) => Measurement.fromJson(jsonDecode(s));
}
