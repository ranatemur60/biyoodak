import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../analysis/scoring.dart';
import '../models.dart';
import '../services/screen_time.dart';
import '../services/storage.dart';
import '../vision/vision_source.dart';
import '../widgets/common.dart';
import 'result.dart';

const kLightConditions = [
  'Önden yeterli ışık',
  'Karanlık ortam',
  'Arkadan ışık',
];

/// 45 saniyelik eş zamanlı ölçüm: PERCLOS + rPPG + reaksiyon/bildirim tepkisi
/// + bakış kayması.
class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});
  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

enum _Phase { intro, starting, waitingFace, countdown, recording, fatigue, done }

class _MeasureScreenState extends State<MeasureScreen> {
  static const durationMs = 45000.0;
  _Phase phase = _Phase.intro;
  String light = kLightConditions[0];
  String? error;
  VisionSource? vision;
  StreamSubscription<FrameSample>? sub;
  SessionData? data;
  final sw = Stopwatch();
  Timer? ticker;
  int countdown = 3;
  bool faceNow = false;
  double lastFaceT = -1;
  int fatigue = 5;

  // Uyaranlar
  final rnd = math.Random();
  List<double> stimTimes = [];
  double notifTime = 0;
  int nextStim = 0;
  double? stimShownAt; // stopwatch ms
  Offset stimPos = const Offset(0.5, 0.5);
  bool notifVisible = false;
  bool notifDone = false;
  double? notifShownAt;

  @override
  void dispose() {
    ticker?.cancel();
    sub?.cancel();
    vision?.stop();
    super.dispose();
  }

  void _schedule() {
    // 6 uyaran 4-42 sn arasında, en az 4 sn aralıkla; bildirim 15-35 sn arasında
    stimTimes = [];
    notifTime = 15000 + rnd.nextDouble() * 20000;
    var t = 3000.0;
    while (stimTimes.length < 6) {
      t += 4000 + rnd.nextDouble() * 2500;
      if (t > 42000) break;
      if ((t - notifTime).abs() < 2500) t += 2500;
      stimTimes.add(t);
    }
    nextStim = 0;
    notifDone = false;
  }

  Future<void> _start() async {
    setState(() {
      phase = _Phase.starting;
      error = null;
    });
    try {
      final v = VisionSource.create();
      vision = v;
      await v.start();
      sub = v.samples.listen(_onSample);
      setState(() => phase = _Phase.waitingFace);
      // En fazla 15 sn yüz bekle
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (mounted && phase == _Phase.waitingFace) {
        if (faceNow) {
          _countdown();
          return;
        }
        if (DateTime.now().isAfter(deadline)) {
          setState(() => error =
              'Yüz algılanamadı. Yüzünü çerçevenin ortasına getir ve önden ışık aldığından emin ol.');
          await _cancel();
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      await _cancel();
      setState(() {
        phase = _Phase.intro;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _cancel() async {
    ticker?.cancel();
    await sub?.cancel();
    sub = null;
    await vision?.stop();
    vision = null;
    if (mounted) setState(() => phase = _Phase.intro);
  }

  void _countdown() {
    setState(() {
      phase = _Phase.countdown;
      countdown = 3;
    });
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (countdown <= 1) {
        t.cancel();
        _record();
      } else {
        setState(() => countdown--);
      }
    });
  }

  void _record() {
    data = SessionData(
        start: DateTime.now(), durationMs: durationMs, lightCondition: light);
    _schedule();
    sw
      ..reset()
      ..start();
    setState(() => phase = _Phase.recording);
    ticker = Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
  }

  double get _now => sw.elapsedMicroseconds / 1000.0;

  void _onSample(FrameSample s) {
    if (s.isLandmark) {
      faceNow = s.face;
    }
    final d = data;
    if (d == null || phase != _Phase.recording) return;
    final t = _now;
    if (s.isLandmark) {
      d.lmT.add(t);
      d.ear.add(s.face ? s.ear : null);
      d.face.add(s.face);
      d.offFocus.add(s.offFocus);
    } else if (s.g != null) {
      d.colorT.add(t);
      d.green.add(s.g!);
      d.luma.add(0.299 * s.r! + 0.587 * s.g! + 0.114 * s.b!);
    }
  }

  void _tick() {
    final t = _now;
    final d = data!;
    // Uyaran zaman aşımı (1.5 sn) → kaçırıldı
    if (stimShownAt != null && t - stimShownAt! > 1500) {
      d.reactionMs.add(null);
      stimShownAt = null;
    }
    if (stimShownAt == null && nextStim < stimTimes.length && t >= stimTimes[nextStim]) {
      nextStim++;
      stimShownAt = t;
      stimPos = Offset(0.2 + rnd.nextDouble() * 0.6, 0.35 + rnd.nextDouble() * 0.4);
    }
    if (!notifDone && !notifVisible && t >= notifTime) {
      notifVisible = true;
      notifShownAt = t;
    }
    if (notifVisible && t - notifShownAt! > 4000) {
      notifVisible = false;
      notifDone = true; // kaçırıldı
    }
    if (t >= durationMs) {
      _finishRecording();
      return;
    }
    setState(() {});
  }

  void _onTapScreen() {
    if (phase != _Phase.recording) return;
    final t = _now;
    if (stimShownAt != null) {
      data!.reactionMs.add(t - stimShownAt!);
      stimShownAt = null;
    } else {
      data!.falseStarts++;
    }
    setState(() {});
  }

  void _onTapNotif() {
    if (!notifVisible) return;
    data!.notifReactionMs = _now - notifShownAt!;
    notifVisible = false;
    notifDone = true;
    setState(() {});
  }

  Future<void> _finishRecording() async {
    ticker?.cancel();
    sw.stop();
    if (stimShownAt != null) {
      data!.reactionMs.add(null);
      stimShownAt = null;
    }
    await sub?.cancel();
    sub = null;
    await vision?.stop();
    vision = null;
    if (mounted) setState(() => phase = _Phase.fatigue);
  }

  Future<void> _compute() async {
    setState(() => phase = _Phase.done);
    final stats = await ScreenTime.stats();
    final profile = Store.profile;
    final night = (stats.supported && stats.enabled && stats.nightMin > 0)
        ? stats.nightMin.toDouble()
        : profile.nightVideoMinutes.toDouble();
    final m = computeMeasurement(data!,
        baseline: UserBaseline.fromHistory(Store.history),
        subjectiveFatigue: fatigue,
        nightScreenMin: night);
    await Store.addMeasurement(m);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => ResultScreen(m: m, fresh: true)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ölçüm')),
      body: switch (phase) {
        _Phase.intro => _intro(),
        _Phase.fatigue => _fatigue(),
        _Phase.done => const Center(child: CircularProgressIndicator()),
        _ => _camera(),
      },
    );
  }

  Widget _intro() => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Ölçüm nasıl yapılır?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('1. Telefonu masaya/standa yasla, yüzün ön kameraya 30-40 cm uzaklıkta olsun.\n'
            '2. Yüzün önden aydınlık olsun; arkanda pencere veya lamba olmasın.\n'
            '3. Ölçüm 45 saniye sürer. Bu sürede başını sabit tut ve ekrana bak.\n'
            '4. Ekranda renkli bir daire belirdiğinde ekranın herhangi bir yerine olabildiğince hızlı dokun.\n'
            '5. Üstten bir bildirim kayarsa ona dokun.'),
        const SizedBox(height: 16),
        const Text('Ortam koşulu (Teknik doğrulama için)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [
          for (final l in kLightConditions)
            ChoiceChip(label: Text(l), selected: light == l, onSelected: (_) => setState(() => light = l)),
        ]),
        if (error != null) ...[
          const SizedBox(height: 16),
          Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(padding: const EdgeInsets.all(12), child: Text(error!))),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Ölçümü Başlat')),
        const SizedBox(height: 12),
        const Text(
            'Kamera görüntüsü kaydedilmez; yalnızca cihaz üzerinde anlık işlenir.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12)),
      ]);

  Widget _camera() {
    final t = phase == _Phase.recording ? _now : 0.0;
    final remaining = ((durationMs - t) / 1000).ceil().clamp(0, 45);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        // Bildirim alanına dokunma ayrı değerlendirilir
        if (notifVisible && e.localPosition.dy < 100) {
          _onTapNotif();
        } else {
          _onTapScreen();
        }
      },
      child: Stack(fit: StackFit.expand, children: [
        if (vision != null)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(width: 240, height: 320, child: vision!.preview()),
            ),
          ),
        // Yüz kılavuzu
        IgnorePointer(
          child: Center(
            child: Container(
              width: 180,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: faceNow ? kGreen : kRed, width: 3),
                borderRadius: const BorderRadius.all(Radius.elliptical(90, 120)),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Column(children: [
            Text(
              switch (phase) {
                _Phase.starting => 'Kamera ve yüz analizi hazırlanıyor...',
                _Phase.waitingFace => 'Yüzünü çerçevenin içine getir',
                _Phase.countdown => 'Başlıyor: $countdown',
                _ => faceNow ? 'Ölçülüyor... $remaining sn' : '⚠️ Yüz görünmüyor',
              },
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (phase == _Phase.recording)
              LinearProgressIndicator(value: (t / durationMs).clamp(0, 1)),
            const SizedBox(height: 8),
            TextButton(onPressed: _cancel, child: const Text('İptal')),
          ]),
        ),
        if (stimShownAt != null)
          LayoutBuilder(builder: (ctx, c) {
            return Stack(children: [
              Positioned(
                left: stimPos.dx * c.maxWidth - 40,
                top: stimPos.dy * c.maxHeight - 40,
                child: IgnorePointer(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(color: Color(0xFFFF7A00), shape: BoxShape.circle),
                  ),
                ),
              ),
            ]);
          }),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          left: 12,
          right: 12,
          top: notifVisible ? 12 : -120,
          child: IgnorePointer(
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              child: const ListTile(
                leading: Icon(Icons.notifications_active, color: kPrimary),
                title: Text('BiyoOdak'),
                subtitle: Text('Yeni bildirim: dokunarak kapat'),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _fatigue() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Kendini şu an ne kadar yorgun hissediyorsun?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('0: Hiç yorgun değilim · 10: Çok yorgunum'),
          const SizedBox(height: 16),
          Text('$fatigue / 10', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Slider(
              value: fatigue.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: (v) => setState(() => fatigue = v.round())),
          const SizedBox(height: 16),
          FilledButton(onPressed: _compute, child: const Text('Sonucu Göster')),
        ]),
      );
}

/// Ölçüm sonucunun düz metin özeti (rapordaki "ÖLÇÜM SONUCU" görünümü).
String summaryText(Measurement m) {
  String f(double? v, [String u = ' ms']) => v == null ? 'ölçülemedi' : '${v.toStringAsFixed(0)}$u';
  return 'PERCLOS: %${m.perclos.toStringAsFixed(1)} | Göz kırpma: ${m.blinks}\n'
      'Nabız: ${m.bpm == null ? 'ölçülemedi' : '${m.bpm!.round()} BPM'} | SNR: ${m.snrDb.toStringAsFixed(1)} dB | HRV/RMSSD: ${m.rmssd == null ? 'ölçülemedi' : '${m.rmssd!.round()} ms'}\n'
      'Reaksiyon: ${f(m.reactionMedianMs)} | Odak dışı: %${m.offFocusPct.round()} | Bildirim tepki: ${f(m.notifReactionMs)}\n'
      'Öznel yorgunluk: ${m.subjectiveFatigue}/10 | Sirkadiyen maruziyet: ${m.circadianExposure.toStringAsFixed(1)}/100 (${exposureLabel(m.circadianExposure)})';
}
