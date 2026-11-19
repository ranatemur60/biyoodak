import 'package:material_ui/material_ui.dart';

import '../analysis/scoring.dart';
import '../models.dart';
import '../services/recommendations.dart';
import '../widgets/common.dart';

/// Teknik Rapor: ham biyometrik veriler, grafikler, formüller ve sirkadiyen
/// ritim analizi.
class TechnicalReportScreen extends StatelessWidget {
  final Measurement m;
  const TechnicalReportScreen({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    String f(double? v, [int d = 1, String u = '']) =>
        v == null ? 'ölçülemedi' : '${v.toStringAsFixed(d)}$u';
    int? peak;
    if (m.spectrum.isNotEmpty) {
      peak = 0;
      for (var i = 1; i < m.spectrum.length; i++) {
        if (m.spectrum[i] > m.spectrum[peak!]) peak = i;
      }
    }
    final mono = Theme.of(context).textTheme.bodySmall!.copyWith(fontFamily: 'monospace');
    return Scaffold(
      appBar: AppBar(title: const Text('Teknik Rapor')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SectionTitle('1. Göz Kırpma Analizi (PERCLOS)'),
        KV('PERCLOS', '%${m.perclos.toStringAsFixed(2)}'),
        KV('Göz kırpma sayısı', '${m.blinks}'),
        KV('Göz kırpma hızı', '${m.blinkRate.toStringAsFixed(1)} /dk'),
        KV('Kişisel açık göz EAR (kalibrasyon)', m.openEar.toStringAsFixed(3)),
        KV('Kapalı göz eşiği (EAR × 0.6)', (m.openEar * 0.6).toStringAsFixed(3)),
        const SizedBox(height: 6),
        const Text('EAR zaman serisi'),
        LineChart(y: m.earSeries, hLine: m.openEar * 0.6, hLineLabel: 'eşik', color: kPrimary),
        Text('EAR = (‖p2−p6‖ + ‖p3−p5‖) / (2‖p1−p4‖)\nPERCLOS = (t_kapalı / t_toplam) × 100', style: mono),
        _src(context, Sources.perclos),

        const SectionTitle('2. Temassız Nabız ve Stres (rPPG)'),
        KV('Tahmini kalp atım hızı', f(m.bpm, 0, ' BPM')),
        KV('Sinyal-gürültü oranı (SNR)', '${m.snrDb.toStringAsFixed(2)} dB'),
        KV('HRV / RMSSD', f(m.rmssd, 0, ' ms')),
        KV('Biyolojik stres düzeyi', m.stress),
        KV('Kamera örnekleme hızı', '${m.cameraFps.toStringAsFixed(1)} fps'),
        KV('Ölçüm süresi', '${m.durationS.round()} sn'),
        const SizedBox(height: 6),
        const Text('Filtrelenmiş alın sinyali (0.7–3.5 Hz bant geçiren)'),
        LineChart(y: m.ppgSignal, color: kGreen),
        const Text('Fourier güç spektrumu (0.7–3.5 Hz ≈ 42–210 BPM)'),
        LineChart(y: m.spectrum, color: kRed, markIndex: peak),
        Text('C(t) = (1/|ROI|) · Σ I_G(x, y, t)\nBPM = 60 × f_baskın\nSNR = 10·log10(P_sinyal / P_gürültü)', style: mono),
        const SizedBox(height: 4),
        Text(
            'Not: HRV, nabız sinyalindeki atımlar arası sürelerden hesaplanır (en az 25 sn kayıt, SNR > -3 dB, en az 15 geçerli atım). Işık zayıfsa veya baş hareket ederse "ölçülemedi" gösterilir.',
            style: Theme.of(context).textTheme.bodySmall),
        _src(context, Sources.rppg),
        _src(context, Sources.snr),

        const SectionTitle('3. Reaksiyon ve Bildirim Tepki Analizi'),
        KV('Reaksiyon süresi (medyan)', f(m.reactionMedianMs, 0, ' ms')),
        KV('Reaksiyon süresi (ortalama)', f(m.reactionMeanMs, 0, ' ms')),
        KV('Uyaran / yanıt', '${m.stimuli} / ${m.answered}'),
        KV('Gecikme (>500 ms veya kaçırılan)', '${m.lapses}'),
        KV('Erken/yanlış dokunma', '${m.falseStarts}'),
        KV('Bildirim tepki süresi', f(m.notifReactionMs, 0, ' ms')),
        KV('Odak dışı süre (bakış kayması)', '%${m.offFocusPct.toStringAsFixed(1)}'),
        _src(context, Sources.pvt),
        _src(context, Sources.reaction),

        const SectionTitle('4. Sirkadiyen Ritim Analizi'),
        KV('Gece ekran süresi (22:00–06:00)', '${m.nightScreenMin.round()} dk'),
        KV('Tahmini melatonin oranı (M/M_bazal)', m.melatoninRatio.toStringAsFixed(3)),
        KV('Tahmini melatonin baskılanması', '%${((1 - m.melatoninRatio) * 100).toStringAsFixed(1)}'),
        KV('Sirkadiyen maruziyet', '${m.circadianExposure.toStringAsFixed(1)}/100 (${exposureLabel(m.circadianExposure)})'),
        Text('M_tahmin = M_bazal · e^(−k·L·t)\nk = 0.006 (lüks·saat)⁻¹, L = 40 lüks (gece ekran), t = saat', style: mono),
        const SizedBox(height: 4),
        Text(
            'Bu değer teorik bir matematiksel modeldir; melatonin doğrudan ölçülmemektedir. Gece mavi ışığı (450–480 nm) ipRGC hücreleri üzerinden SCN\'yi uyararak melatonin salınımını baskılayabilir.',
            style: Theme.of(context).textTheme.bodySmall),
        _src(context, Sources.eReader),
        _src(context, Sources.roomLight),

        const SectionTitle('5. Bileşik Gösterge ve Güven Skoru'),
        KV('Göz puanı', '${m.eyeScore.round()}/100'),
        KV('Nabız puanı', m.pulseScore == null ? 'ölçülemedi' : '${m.pulseScore!.round()}/100'),
        KV('Reaksiyon puanı', '${m.reactionScore.round()}/100'),
        KV('Odak puanı', '${m.focusScore.round()}/100'),
        KV('Bileşik gösterge', '${m.composite.round()}/100'),
        KV('Güven skoru', '${m.confidence.round()}/100'),
        KV('Ortam koşulu', m.lightCondition),
        KV('Yüz bölgesi parlaklığı (0–255)', m.faceBrightness.toStringAsFixed(0)),
        Text('Gösterge = 0.4·Göz + 0.4·(0.7·Reaksiyon + 0.3·Odak) + 0.2·Nabız\n(Nabız ölçülemezse: 0.5·Göz + 0.5·Tepki)', style: mono),
        const SizedBox(height: 4),
        Text(
            'Kişisel kalibrasyon: İlk 3 ölçümden sonra reaksiyon ve nabız puanları kullanıcının kendi temel değerlerine göre hesaplanır. Kural tabanlı karar destek algoritmasıdır; tıbbi tanı koymaz.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _src(BuildContext context, Source s) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => showSource(context, s),
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: Text(s.citation.split('(').first.trim(), overflow: TextOverflow.ellipsis),
        ),
      );
}
