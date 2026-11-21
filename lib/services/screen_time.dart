import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'storage.dart';

/// Ekran süresi istatistikleri.
class ScreenStats {
  final bool supported; // Arka planda telefon geneli takip (yalnızca Android)
  final bool enabled;
  final int todayMin;
  final int currentUseMin;
  final int nightMin;
  final int alertsSent;
  final List<int> notifLatenciesMs;
  final bool notifAllowed;
  final bool batteryOk;
  const ScreenStats({
    this.notifAllowed = true,
    this.batteryOk = true,
    this.supported = false,
    this.enabled = false,
    this.todayMin = 0,
    this.currentUseMin = 0,
    this.nightMin = 0,
    this.alertsSent = 0,
    this.notifLatenciesMs = const [],
  });
}

/// Akıllı Mola Bildirimleri: Android'de arka plan servisi telefonun
/// sürekli kullanım süresini izler; 30, 45 ve 60. dakikada uyarır,
/// 30 dakikalık moladan (ekran kapalı) sonra sayaç sıfırlanır.
class ScreenTime {
  static const _ch = MethodChannel('biyoodak/screen');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> requestNotificationPermission() async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  static Future<void> start({String name = '', bool student = false, String exam = ''}) async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('start', {
        'student': student,
        'exam': exam,
        'thresholds': [30, 45, 60],
        'resetMin': 30, // ekran 30 dk kapalı kalırsa sayaç sıfırlanır
        'name': name,
      });
    } catch (_) {}
  }

  static Future<void> _call(String m) async {
    if (!supported) return;
    try {
      await _ch.invokeMethod(m);
    } catch (_) {}
  }

  static Future<void> sendTest() => _call('test');
  static Future<void> openNotifSettings() => _call('openNotifSettings');
  static Future<void> requestBattery() => _call('requestBattery');

  static Future<void> stop() async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }

  static Future<ScreenStats> stats() async {
    if (!supported) {
      return ScreenStats(todayMin: WebUsage.todaySec ~/ 60);
    }
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('stats');
      if (m == null) return const ScreenStats(supported: true);
      return ScreenStats(
        supported: true,
        enabled: m['enabled'] == true,
        todayMin: (m['todayMin'] ?? 0) as int,
        currentUseMin: (m['currentUseMin'] ?? 0) as int,
        nightMin: (m['nightMin'] ?? 0) as int,
        alertsSent: (m['alertsSent'] ?? 0) as int,
        notifAllowed: m['notifAllowed'] != false,
        batteryOk: m['batteryOk'] != false,
        notifLatenciesMs: ((m['latencies'] ?? const []) as List)
            .map((e) => (e as num).toInt())
            .toList(),
      );
    } catch (_) {
      return const ScreenStats(supported: true);
    }
  }
}

/// Web sürümünde yalnızca uygulama içinde geçen süre sayılır (tarayıcı,
/// telefonun genel kullanımını okuyamaz).
class WebUsage {
  static Timer? _timer;
  static final _alertCtrl = StreamController<int>.broadcast();
  static Stream<int> get alerts => _alertCtrl.stream;
  static int _sessionSec = 0;
  static int get sessionMin => _sessionSec ~/ 60;

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  static int get todaySec =>
      Store.webUsageDay == _today() ? Store.webUsageSec : 0;

  static void startTicking() {
    if (ScreenTime.supported || _timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (Store.webUsageDay != _today()) {
        Store.webUsageDay = _today();
        Store.webUsageSec = 0;
      }
      Store.webUsageSec = Store.webUsageSec + 10;
      _sessionSec += 10;
      for (final m in const [30, 45, 60]) {
        if (_sessionSec == m * 60) _alertCtrl.add(m);
      }
    });
  }
}
