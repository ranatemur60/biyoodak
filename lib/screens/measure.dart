import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../analysis/scoring.dart';
import '../models.dart';
import '../services/screen_time.dart';
import '../services/session.dart';
import '../services/storage.dart';
import '../vision/vision_source.dart';
import '../widgets/common.dart';
import 'result.dart';

const kLightConditions = [
  'Önden yeterli ışık',
  'Karanlık ortam',
  'Arkadan ışık',
];

/// Ölçüm türleri: tam ölçüm veya tek tek modüller.
enum MeasureMode { full, pulse, eye, reaction }

class _ModeInfo {
  final String title, cardTitle, emoji;
  final double seconds;
  final List<Color> colors;
  final Color accent;
  final String howTo;
  const _ModeInfo(this.title, this.cardTitle, this.emoji, this.seconds,
      this.colors, this.accent, this.howTo);
}

const _modes = {
  MeasureMode.full: _ModeInfo(
      'Tam Ölçüm',
      'Göz • Nabız • Dikkat',
      '🧠',
      45,
      gPurple,
      kPrimary,
      'Telefonu sabit bir yere yasla, yüzün 30-40 cm uzakta olsun. 45 saniye boyunca ekrana bak. '
          'Yeşil daire belirdiğinde ekrana dokun. Mor kareyi gördüğünde bekle. Üstten bildirim gelirse ona dokun.'),
  MeasureMode.pulse: _ModeInfo(
      'Nabız Ölçümü',
      'Nabız analizi',
      '❤️',
      45,
      gPink,
      kPink,
      'Telefonu yüzünün karşısında tut ve yüzünü çerçevenin içine getir. Ölçüm 45 saniye sürer. Bu sürede konuşma ve başını sabit tut. '
          'Yüzünün önden aydınlık olması ölçümü iyileştirir.'),
  MeasureMode.eye: _ModeInfo(
      'Göz Analizi',
      'Göz analizi',
      '👁️',
      30,
      gBlue,
      kTeal,
      'Telefonu yüzünün karşısında tut ve 30 saniye boyunca normal şekilde ekrana bak. '
          'Göz kırpmalarını bastırmaya çalışma.'),
  MeasureMode.reaction: _ModeInfo(
      'Tepki Hızı',
      'Tepki hızı',
      '⚡',
      30,
      gOrange,
      kOrange,
      'Yeşil daire belirdiğinde ekranın herhangi bir yerine hızlıca dokun. '
          'Mor kareyi gördüğünde bekle, dokunma. Üstten bildirim gelirse ona dokun.'),
};

class MeasureScreen extends StatefulWidget {
  final MeasureMode mode;
  const MeasureScreen({super.key, this.mode = MeasureMode.full});
  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

enum _Phase { intro, starting, waitingFace, countdown, recording, fatigue, done }

class _Stim {
  final double t;
  final bool go;
  _Stim(this.t, this.go);
}

class _MeasureScreenState extends State<MeasureScreen> {
  late final _ModeInfo info = _modes[widget.mode]!;
  double get durationMs => info.seconds * 1000;
  bool get hasStimuli =>
      widget.mode == MeasureMode.full || widget.mode == MeasureMode.reaction;

  _Phase phase = _Phase.intro;
  String light = kLightConditions[0];
  String? error;
  String? visionError;
  VisionSource? vision;
  StreamSubscription<FrameSample>? sub;
  SessionData? data;
  final sw = Stopwatch();
  Timer? ticker;
  int countdown = 3;
  bool faceNow = false;
  int fatigue = 5;

  // Go/No-Go uyaranları
  final rnd = math.Random();
  List<_Stim> stims = [];
  double notifTime = 0;
  int nextStim = 0;
  double? stimShownAt;
  bool stimGo = true;
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
    stims = [];
    nextStim = 0;
    notifDone = !hasStimuli;
    if (!hasStimuli) return;
    final end = durationMs - 3000;
    notifTime = durationMs * (0.35 + rnd.nextDouble() * 0.4);
    final gap = widget.mode == MeasureMode.full ? 4000.0 : 2600.0;
    var t = 2500.0;
    while (true) {
      t += gap + rnd.nextDouble() * 1800;
      if (t > end) break;
      if ((t - notifTime).abs() < 2500) t += 2500;
      if (t > end) break;
      stims.add(_Stim(t, true));
    }
    // Yaklaşık %25'i "bekle" (mor kare); ilk uyaran her zaman yeşil.
    final nogo = (stims.length / 4).round();
    final idx = List<int>.generate(stims.length - 1, (i) => i + 1)..shuffle(rnd);
    for (final i in idx.take(nogo)) {
      stims[i] = _Stim(stims[i].t, false);
    }
  }

  Future<void> _start() async {
    setState(() {
      phase = _Phase.starting;
      error = null;
      visionError = null;
    });
    try {
      final v = VisionSource.create();
      vision = v;
      await v.start();
      sub = v.samples.listen(_onSample, onError: (Object e) {
        if (mounted) {
          setState(() => visionError = e.toString().replaceFirst('Exception: ', ''));
        }
      });
      setState(() => phase = _Phase.waitingFace);
      // Yüz en fazla 6 sn beklenir; bulunamazsa ölçüm yine başlar ve
      // ekranda uyarı gösterilir.
      final deadline = DateTime.now().add(const Duration(seconds: 6));
      while (mounted && phase == _Phase.waitingFace) {
        if (faceNow || DateTime.now().isAfter(deadline)) {
          _countdown();
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      await _cancel();
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _cancel() async {
    ticker?.cancel();
    await sub?.cancel();
    sub = null;
    await vision?.stop();
    vision = null;
    stimShownAt = null;
    notifVisible = false;
    if (mounted) setState(() => phase = _Phase.intro);
  }

  void _countdown() {
    setState(() {
      phase = _Phase.countdown;
      countdown = 3;
    });
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || phase != _Phase.countdown) return t.cancel();
      if (countdown <= 1) {
        t.cancel();
        _record();
      } else {
        setState(() => countdown--);
      }
    });
  }

  void _record() {
    final d = SessionData(
        start: DateTime.now(), durationMs: durationMs, lightCondition: light);
    switch (widget.mode) {
      case MeasureMode.full:
        d.pulseDone = d.eyeDone = d.reactionDone = true;
      case MeasureMode.pulse:
        d.pulseDone = true;
      case MeasureMode.eye:
        d.eyeDone = true;
      case MeasureMode.reaction:
        d.reactionDone = true;
    }
    data = d;
    _schedule();
    sw
      ..reset()
      ..start();
    setState(() => phase = _Phase.recording);
    ticker = Timer.periodic(const Duration(milliseconds: 30), (_) => _tick());
  }

  double get _now => sw.elapsedMicroseconds / 1000.0;

  void _onSample(FrameSample s) {
    if (s.isLandmark) faceNow = s.face;
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
    if (stimShownAt != null) {
      final age = t - stimShownAt!;
      if (stimGo && age > 1500) {
        d.reactionMs.add(null); // kaçırıldı
        stimShownAt = null;
      } else if (!stimGo && age > 1200) {
        stimShownAt = null; // doğru bekledi
      }
    }
    if (stimShownAt == null && nextStim < stims.length && t >= stims[nextStim].t) {
      stimGo = stims[nextStim].go;
      if (!stimGo) d.nogoTotal++;
      nextStim++;
      stimShownAt = t;
      stimPos = Offset(0.2 + rnd.nextDouble() * 0.6, 0.25 + rnd.nextDouble() * 0.4);
    }
    if (!notifDone && !notifVisible && t >= notifTime) {
      notifVisible = true;
      notifShownAt = t;
      d.notifShown = true;
    }
    if (notifVisible && t - notifShownAt! > 4000) {
      notifVisible = false;
      notifDone = true;
    }
    if (t >= durationMs) {
      _finishRecording();
      return;
    }
    setState(() {});
  }

  void _onTapScreen() {
    if (phase != _Phase.recording || !hasStimuli) return;
    final t = _now;
    final d = data!;
    if (stimShownAt != null && stimGo) {
      d.reactionMs.add(t - stimShownAt!);
      stimShownAt = null;
    } else if (stimShownAt != null && !stimGo) {
      d.nogoErrors++;
      d.falseStarts++;
      stimShownAt = null;
    } else {
      d.falseStarts++;
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
    if (stimShownAt != null && stimGo) data!.reactionMs.add(null);
    stimShownAt = null;
    notifVisible = false;
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
    final d = data!;
    // Ortam ışığı yüz parlaklığından otomatik belirlenir.
    if (d.luma.isNotEmpty) {
      final avg = d.luma.reduce((a, b) => a + b) / d.luma.length;
      d.lightCondition = avg < 70 ? 'Karanlık ortam' : 'Önden yeterli ışık';
    }
    light = d.lightCondition;
    SessionData acc;
    if (widget.mode == MeasureMode.full) {
      CurrentSession.replaceWith(d);
      acc = d;
    } else {
      acc = CurrentSession.accumulator(light)..mergeFrom(d);
    }
    final m = computeMeasurement(acc,
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
      appBar: AppBar(
        title: Text(info.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: switch (phase) {
        _Phase.intro => _intro(),
        _Phase.fatigue => _fatigue(),
        _Phase.done => const Center(child: CircularProgressIndicator()),
        _ => _camera(),
      },
    );
  }

  Widget _intro() => ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        GradientCard(
          colors: info.colors,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(info.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${info.title} (${info.seconds.round()} sn)',
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: kNavy)),
              ),
            ]),
            const SizedBox(height: 14),
            Text(info.howTo, style: const TextStyle(fontSize: 15.5, height: 1.45, color: kNavy)),
          ]),
        ),
        if (hasStimuli) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _legendBox(true)),
            const SizedBox(width: 12),
            Expanded(child: _legendBox(false)),
          ]),
        ],
        const SizedBox(height: 4),
        if (error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFFE8EA), borderRadius: BorderRadius.circular(18)),
            child: Text(error!, style: const TextStyle(color: kNavy)),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Ölçümü Başlat')),
        const SizedBox(height: 14),
        const Text('Kamera görüntüsü kaydedilmez; yalnızca cihaz üzerinde anlık işlenir.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: kMuted)),
      ]);

  Widget _legendBox(bool go) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF6F4FB), borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          _shape(go, 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(go ? 'Yeşil daire: dokun' : 'Mor kare: bekle',
                style: const TextStyle(fontWeight: FontWeight.w700, color: kNavy)),
          ),
        ]),
      );

  Widget _shape(bool go, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: go ? kGreen : kPrimary,
          shape: go ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: go ? null : BorderRadius.circular(size * 0.18),
        ),
      );

  Widget _camera() {
    final t = phase == _Phase.recording ? _now : 0.0;
    final remaining = ((durationMs - t) / 1000).ceil().clamp(0, info.seconds.round());
    final status = switch (phase) {
      _Phase.starting => 'Kamera hazırlanıyor...',
      _Phase.waitingFace => 'Telefonu yüzüne doğru tut, yüzünü çerçeveye getir',
      _Phase.countdown => 'Başlıyor: $countdown',
      _ => faceNow ? 'Ölçülüyor... $remaining sn' : 'Yüz görünmüyor · $remaining sn',
    };
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (notifVisible && e.localPosition.dy < 110) {
          _onTapNotif();
        } else {
          _onTapScreen();
        }
      },
      child: Stack(fit: StackFit.expand, children: [
        Column(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(fit: StackFit.expand, children: [
                      Container(color: const Color(0xFF14121F)),
                      if (vision != null) vision!.preview(),
                      IgnorePointer(
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.7,
                            heightFactor: 0.72,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: faceNow ? kTeal : kRed, width: 3),
                                borderRadius: BorderRadius.circular(36),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: GradientCard(
              colors: info.colors,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${info.emoji} ${info.cardTitle}',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kNavy)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: phase == _Phase.recording ? (t / durationMs).clamp(0, 1) : 0,
                    color: info.accent,
                    backgroundColor: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 10),
                Text(status,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: phase == _Phase.recording && !faceNow ? kRed : kNavy)),
                if (visionError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(visionError!, style: const TextStyle(fontSize: 12.5, color: kRed)),
                  ),
                if (hasStimuli)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Yeşil daire belirdiğinde dokun. Mor kareyi gördüğünde bekle.',
                        style: TextStyle(fontSize: 13.5, color: kMuted)),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _cancel, child: const Text('İptal')),
                ),
              ]),
            ),
          ),
        ]),
        if (stimShownAt != null)
          LayoutBuilder(builder: (ctx, c) {
            return Stack(children: [
              Positioned(
                left: stimPos.dx * c.maxWidth - 45,
                top: stimPos.dy * c.maxHeight - 45,
                child: IgnorePointer(child: _shape(stimGo, 90)),
              ),
            ]);
          }),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          left: 12,
          right: 12,
          top: notifVisible ? 10 : -130,
          child: IgnorePointer(
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              child: const ListTile(
                leading: Icon(Icons.notifications_active, color: kPrimary),
                title: Text('NeuroVibe', style: TextStyle(fontWeight: FontWeight.w800)),
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
          const Text('😴', style: TextStyle(fontSize: 54)),
          const SizedBox(height: 12),
          const Text('Kendini şu an ne kadar yorgun hissediyorsun?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: kNavy)),
          const SizedBox(height: 8),
          const Text('0: Hiç yorgun değilim · 10: Çok yorgunum', style: TextStyle(color: kMuted)),
          const SizedBox(height: 18),
          Text('$fatigue / 10',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: kPrimary)),
          Slider(
              value: fatigue.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: (v) => setState(() => fatigue = v.round())),
          const SizedBox(height: 18),
          FilledButton(onPressed: _compute, child: const Text('Karnemi Göster')),
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
