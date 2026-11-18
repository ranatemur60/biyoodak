import '../analysis/scoring.dart';

/// Ayrı ayrı yapılan ölçümleri (Nabız, Göz, Tepki) tek bir oturum
/// karnesinde birleştirir. 60 dakika ölçüm yapılmazsa yeni karne başlar.
class CurrentSession {
  static SessionData? _acc;
  static DateTime? _last;

  static SessionData accumulator(String light) {
    final now = DateTime.now();
    if (_acc == null ||
        _last == null ||
        now.difference(_last!) > const Duration(minutes: 60)) {
      _acc = SessionData(start: now, durationMs: 45000, lightCondition: light);
    }
    _last = now;
    return _acc!;
  }

  /// Tam ölçüm her zaman yeni bir karne başlatır.
  static void replaceWith(SessionData d) {
    _acc = d;
    _last = DateTime.now();
  }

  static void reset() {
    _acc = null;
    _last = null;
  }
}
