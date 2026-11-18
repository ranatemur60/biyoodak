import 'package:material_ui/material_ui.dart';

import '../analysis/scoring.dart';
import '../models.dart';
import '../services/recommendations.dart';
import '../services/storage.dart';
import '../widgets/common.dart';
import 'measure.dart';
import 'technical_report.dart';

class ResultScreen extends StatelessWidget {
  final Measurement m;
  final bool fresh;
  const ResultScreen({super.key, required this.m, this.fresh = false});

  @override
  Widget build(BuildContext context) {
    final advice = smartAdvice(m, Store.profile);
    final t = m.time;
    String two(int v) => v.toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: const Text('Ölçüm Sonucu')),
      body: Column(children: [
        const DisclaimerBar(),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Center(
                child: Text(
                    '${two(t.day)}.${two(t.month)}.${t.year}  ${two(t.hour)}:${two(t.minute)} · ${m.lightCondition}',
                    style: Theme.of(context).textTheme.labelMedium)),
            const SizedBox(height: 8),
            const Center(
                child: Text('Bilişsel Yorgunluk ve Odaklanma Göstergesi',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            Center(child: FocusGauge(score: m.composite, size: 210)),
            const SizedBox(height: 8),
            const LevelLegend(),
            const SizedBox(height: 16),
            _ConfidenceCard(m),
            const SectionTitle('Ölçüm Sonucu'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(summaryText(m), style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 6),
                  Text('GENEL GÜVEN SKORU: ${m.confidence.round()}/100',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            const SectionTitle('Modül Puanları'),
            _ScoreBar('Göz (PERCLOS)', m.eyeScore),
            _ScoreBar('Nabız (rPPG)', m.pulseScore),
            _ScoreBar('Reaksiyon ve bildirim tepkisi', m.reactionScore),
            _ScoreBar('Odaklanma (bakış)', m.focusScore),
            const SectionTitle('Akıllı Mola Önerisi ve Akıllı Öneriler'),
            for (final a in advice) AdviceTile(a),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute<void>(builder: (_) => TechnicalReportScreen(m: m))),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Teknik Rapor')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute<void>(builder: (_) => const DetailedAdviceScreen())),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('Detaylı Rapor')),
              ),
            ]),
            const SizedBox(height: 16),
            const Text(
                'Sistem tıbbi tanı koyma amacı taşımaz; çıktılar profesyonel tıbbi değerlendirmenin yerine geçmez.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  final Measurement m;
  const _ConfidenceCard(this.m);
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ölçüm Güven Skoru', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('%${m.confidence.round()}',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
          KV('Göz analizi', '%${m.eyeQ.round()}'),
          KV('Nabız sinyali', '%${m.pulseQ.round()}'),
          KV('Tepki hızı', '%${m.reactionQ.round()}'),
          KV('Odaklanma', '%${m.focusQ.round()}'),
          const SizedBox(height: 6),
          Text(
              'Yüzdeler veri ve sinyal kalitesini yaklaşık olarak gösterir; ölçüm doğruluğu veya sağlık durumu yüzdesi değildir. Genel skor, mevcut ölçümlerin ortalamasıdır.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double? v;
  const _ScoreBar(this.label, this.v);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label)),
            Text(v == null ? 'ölçülemedi' : '${v!.round()}/100',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (v ?? 0) / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: v == null ? Colors.grey : levelColor(v!),
          ),
        ]),
      );
}

/// Detaylı Rapor: Genel öneriler + kaynaklar.
class DetailedAdviceScreen extends StatelessWidget {
  const DetailedAdviceScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detaylı Rapor')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('💡 Genel Öneriler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final a in generalAdvice) AdviceTile(a),
          const SizedBox(height: 12),
          Text('Önerilerin yanındaki kitap simgesine dokunarak bilimsel kaynağı görebilirsin.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

/// Kullanılan seviye bilgisini dışarıya da aç
String levelName(double s) => levelTitle(levelOf(s));
