import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Tüm veriler yalnızca cihazda saklanır (KVKK: sunucuya veri gönderilmez).
class Store {
  static late SharedPreferences _p;
  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  static bool get onboarded => _p.getBool('onboarded_v2') ?? false;
  static set onboarded(bool v) => _p.setBool('onboarded_v2', v);

  static UserProfile get profile {
    final s = _p.getString('profile');
    return s == null ? UserProfile() : UserProfile.fromJson(jsonDecode(s));
  }

  static Future<void> saveProfile(UserProfile u) =>
      _p.setString('profile', jsonEncode(u.toJson()));

  static bool get breakAlerts => _p.getBool('breakAlerts') ?? true;
  static set breakAlerts(bool v) => _p.setBool('breakAlerts', v);

  /// En yeni ölçüm başta.
  static List<Measurement> get history {
    final l = _p.getStringList('history') ?? const [];
    final out = <Measurement>[];
    for (final s in l) {
      try {
        out.add(Measurement.decode(s));
      } catch (_) {}
    }
    return out;
  }

  /// Aynı oturumun karnesi güncellenir (aynı başlangıç zamanı), yoksa eklenir.
  static Future<void> addMeasurement(Measurement m) async {
    final l = List<String>.from(_p.getStringList('history') ?? <String>[]);
    if (l.isNotEmpty) {
      try {
        if (Measurement.decode(l.first).time == m.time) l.removeAt(0);
      } catch (_) {}
    }
    // Grafik verileri yalnızca son 5 ölçümde tutulur
    final updated = [m.encode(), ...l];
    for (var i = 5; i < updated.length; i++) {
      try {
        updated[i] = Measurement.decode(updated[i]).withoutSeries().encode();
      } catch (_) {}
    }
    await _p.setStringList('history', updated.take(300).toList());
  }

  static Future<void> clearHistory() => _p.remove('history');

  /// Web sürümünde uygulama içi ekran süresi.
  static int get webUsageSec => _p.getInt('webUsageSec') ?? 0;
  static set webUsageSec(int v) => _p.setInt('webUsageSec', v);
  static String get webUsageDay => _p.getString('webUsageDay') ?? '';
  static set webUsageDay(String v) => _p.setString('webUsageDay', v);
}

/// CSV dışa aktarma (Ek 3 tablosu ve analiz için).
String historyToCsv(List<Measurement> h) {
  const cols = [
    'tarih', 'ortam_kosulu', 'bilesik_puan', 'guven_skoru', 'perclos_yuzde',
    'goz_kirpma', 'kirpma_dk', 'nabiz_bpm', 'snr_db', 'rmssd_ms', 'stres',
    'reaksiyon_medyan_ms', 'reaksiyon_ort_ms', 'uyaran', 'yanit', 'gecikme',
    'erken_tepki', 'bildirim_tepki_ms', 'odak_disi_yuzde', 'oznel_yorgunluk',
    'gece_ekran_dk', 'melatonin_orani', 'sirkadiyen_maruziyet',
    'yuz_parlakligi', 'kamera_fps', 'goz_q', 'nabiz_q', 'tepki_q', 'odak_q'
  ];
  String f(double? v, [int d = 1]) => v == null ? '' : v.toStringAsFixed(d);
  final rows = <String>[cols.join(';')];
  for (final m in h) {
    rows.add([
      m.time.toIso8601String(), m.lightCondition, f(m.composite), f(m.confidence),
      f(m.perclos, 2), '${m.blinks}', f(m.blinkRate), f(m.bpm), f(m.snrDb, 2),
      f(m.rmssd), m.stress, f(m.reactionMedianMs, 0), f(m.reactionMeanMs, 0),
      '${m.stimuli}', '${m.answered}', '${m.lapses}', '${m.falseStarts}',
      f(m.notifReactionMs, 0), f(m.offFocusPct), '${m.subjectiveFatigue}',
      f(m.nightScreenMin, 0), f(m.melatoninRatio, 3), f(m.circadianExposure),
      f(m.faceBrightness), f(m.cameraFps), f(m.eyeQ), f(m.pulseQ),
      f(m.reactionQ), f(m.focusQ)
    ].join(';'));
  }
  return rows.join('\n');
}
