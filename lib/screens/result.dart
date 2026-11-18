import 'package:material_ui/material_ui.dart';

import '../analysis/scoring.dart';
import '../models.dart';
import '../services/recommendations.dart';
import '../services/storage.dart';
import '../widgets/common.dart';
import 'technical_report.dart';

String _two(int v) => v.toString().padLeft(2, '0');
String karneDate(DateTime t) =>
    '${_two(t.day)}.${_two(t.month)}.${t.year} · ${_two(t.hour)}:${_two(t.minute)}';

bool hasFocusData(Measurement m) => m.eyeDone || m.reactionDone || m.pulseDone;

/// "Bilişsel Yorgunluk Karnesi" başlık kartı (Geçmiş ve Sonuç ekranlarında).
class KarneCard extends StatelessWidget {
  final Measurement m;
  final VoidCallback? onTap;
  const KarneCard({super.key, required this.m, this.onTap});

  @override
  Widget build(BuildContext context) {
    final show = m.hasIndicator;
    final c = show ? levelColor(m.composite) : kMuted;
    return GradientCard(
      colors: gMint,
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bilişsel Yorgunluk Karnesi',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kNavy)),
            const SizedBox(height: 6),
            Text(karneDate(m.time), style: const TextStyle(color: kMuted, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _chip('Nabız', m.pulseDone),
              _chip('Göz', m.eyeDone),
              _chip('Tepki', m.reactionDone),
            ]),
          ]),
        ),
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: c, width: 6),
          ),
          alignment: Alignment.center,
          child: Text(show ? '${m.composite.round()}' : '—',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c)),
        ),
      ]),
    );
  }

  Widget _chip(String t, bool done) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: done ? Colors.white : Colors.white.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('${done ? '✓' : '○'} $t',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: done ? kNavy : kMuted)),
      );
}

/// 2x2 metrik kutuları.
class KarneMetrics extends StatelessWidget {
  final Measurement m;
  const KarneMetrics({super.key, required this.m});
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        MetricTile(
            label: 'Nabız',
            value: !m.pulseDone ? null : (m.bpm == null ? 'Ölçülemedi' : '${m.bpm!.round()} bpm'),
            color: kPink,
            bg: gPink),
        MetricTile(
            label: 'PERCLOS',
            value: m.eyeDone ? '${m.perclos.toStringAsFixed(1)} %' : null,
            color: kTeal,
            bg: gMint),
        MetricTile(
            label: 'Tepki Süresi',
            value: !m.reactionDone
                ? null
                : (m.reactionMedianMs == null ? 'Ölçülemedi' : '${m.reactionMedianMs!.round()} ms'),
            color: kOrange,
            bg: gOrange),
        MetricTile(
            label: 'Odaklanma',
            value: hasFocusData(m) ? '%${m.focusScore.round()}' : null,
            color: kPrimary,
            bg: gPurple),
      ],
    );
  }
}

class ResultScreen extends StatelessWidget {
  final Measurement m;
  final bool fresh;
  const ResultScreen({super.key, required this.m, this.fresh = false});

  @override
  Widget build(BuildContext context) {
    final advice = smartAdvice(m, Store.profile);
    final allDone = m.pulseDone && m.eyeDone && m.reactionDone;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Karnem', style: TextStyle(fontWeight: FontWeight.w800)),
          centerTitle: true),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        KarneCard(m: m),
        const SizedBox(height: 14),
        KarneMetrics(m: m),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 4, children: [
          if (m.eyeDone) Text('Göz kırpma: ${m.blinks}', style: const TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
          if (hasFocusData(m))
            Text('Odak kaybı: %${m.offFocusPct.round()}', style: const TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
          if (m.reactionDone && m.nogoTotal > 0)
            Text('Mor kare hatası: ${m.nogoErrors}/${m.nogoTotal}',
                style: const TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
          if (m.pulseDone && m.bpm != null)
            Text('Stres: ${m.stress}', style: const TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
        ]),
        if (fresh && !allDone) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF3EFFF), borderRadius: BorderRadius.circular(18)),
            child: const Text(
                'Bu karneye 60 dakika içinde yaptığın diğer ölçümler de eklenir. Eksik ölçümleri Ölçüm Merkezi\'nden yapabilirsin.',
                style: TextStyle(color: kNavy)),
          ),
        ],
        const SizedBox(height: 20),
        const _Title('Yorgunluk Risk Göstergesi'),
        if (m.hasIndicator) ...[
          Center(child: FocusGauge(score: m.composite, size: 200)),
          const SizedBox(height: 8),
          const LevelLegend(),
        ] else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF6F4FB), borderRadius: BorderRadius.circular(20)),
            child: const Text(
                'Renkli gösterge için göz analizi, tepki hızı ve odaklanmadan en az ikisini tamamla.',
                style: TextStyle(color: kNavy, height: 1.4)),
          ),
        const SizedBox(height: 20),
        _ConfidenceCard(m),
        const SizedBox(height: 20),
        const _Title('Modül Puanları'),
        _ScoreBar('Göz (PERCLOS)', m.eyeDone, m.eyeScore),
        _ScoreBar('Nabız (rPPG)', m.pulseDone, m.pulseScore),
        _ScoreBar('Tepki ve bildirim tepkisi', m.reactionDone, m.reactionScore),
        _ScoreBar('Odaklanma (bakış)', hasFocusData(m), m.focusScore),
        const SizedBox(height: 20),
        const _Title('Akıllı Öneriler'),
        for (final a in advice) AdviceTile(a),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) => TechnicalReportScreen(m: m))),
                icon: const Icon(Icons.science_outlined),
                label: const Text('Teknik Rapor')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) => const DetailedAdviceScreen())),
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Detaylı Rapor')),
          ),
        ]),
        const SizedBox(height: 16),
        const Text('Bu uygulama tıbbi tanı aracı değildir.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: kMuted)),
      ]),
    );
  }
}

class _Title extends StatelessWidget {
  final String t;
  const _Title(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kNavy)),
      );
}

class _ConfidenceCard extends StatelessWidget {
  final Measurement m;
  const _ConfidenceCard(this.m);
  @override
  Widget build(BuildContext context) {
    String q(bool done, double v) => done ? '%${v.round()}' : 'Veri yetersiz';
    return GradientCard(
      colors: gPurple,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Güven Skoru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kNavy))),
          Text('%${m.confidence.round()}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kPrimary)),
        ]),
        const SizedBox(height: 8),
        KV('Göz analizi', q(m.eyeDone, m.eyeQ)),
        KV('Nabız sinyali', q(m.pulseDone, m.pulseQ)),
        KV('Tepki hızı', q(m.reactionDone, m.reactionQ)),
        KV('Odaklanma', q(hasFocusData(m), m.focusQ)),
        const SizedBox(height: 6),
        const Text(
            'Yüzdeler veri ve sinyal kalitesini gösterir; sağlık durumu yüzdesi değildir.',
            style: TextStyle(fontSize: 12.5, color: kMuted)),
      ]),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final bool done;
  final double? score;
  const _ScoreBar(this.label, this.done, this.score);
  double? get v => done ? score : null;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: const TextStyle(color: kNavy))),
            Text(!done ? 'Tamamlanmadı' : (v == null ? 'Ölçülemedi' : '${v!.round()}/100'),
                style: const TextStyle(fontWeight: FontWeight.w700, color: kNavy)),
          ]),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (v ?? 0) / 100,
            minHeight: 9,
            borderRadius: BorderRadius.circular(5),
            backgroundColor: const Color(0xFFEDEAF5),
            color: v == null ? Colors.grey : levelColor(v!),
          ),
        ]),
      );
}

/// Detaylı Rapor: Genel öneriler + yorgunluğun nasıl belirlendiği.
class DetailedAdviceScreen extends StatelessWidget {
  const DetailedAdviceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    TableRow row(List<String> c, {bool head = false}) => TableRow(
          decoration: head ? const BoxDecoration(color: Color(0xFFEAE4FF)) : null,
          children: [
            for (final t in c)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(t,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: kNavy,
                        fontWeight: head ? FontWeight.w800 : FontWeight.w500)),
              ),
          ],
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Detaylı Rapor')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('💡 Genel Öneriler',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kNavy)),
        const SizedBox(height: 8),
        for (final a in generalAdvice) AdviceTile(a),
        const SizedBox(height: 20),
        const Text('📏 Yorgunluk nasıl belirleniyor?',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kNavy)),
        const SizedBox(height: 8),
        const Text(
            'Bileşik skor = Göz %40 + Tepki %28 + Nabız %20 + Odak %12 (yalnızca tamamlanan ölçümler). '
            'Yeşil 80-100, Sarı 50-79, Kırmızı 0-49.',
            style: TextStyle(color: kNavy, height: 1.4)),
        const SizedBox(height: 10),
        Table(
          border: TableBorder.all(color: const Color(0xFFE0DCEB), borderRadius: BorderRadius.circular(10)),
          columnWidths: const {0: FlexColumnWidth(1.3)},
          children: [
            row(['Gösterge', 'Yeşil', 'Sarı', 'Kırmızı'], head: true),
            row(['PERCLOS', '≤ %8,4', '%8,4-15', '> %15']),
            row(['Tepki (ortanca)', '≤ 368 ms', '368-500 ms', '> 500 ms']),
            row(['Nabız artışı*', '≤ +13', '+13 / +26', '> +26 BPM']),
            row(['Odak kaybı', '≤ %13', '%13-33', '> %33']),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
            '* Kişisel dinlenik nabza göre (yoksa 75 BPM). 500 ms üzeri yanıt veya 1,5 sn içinde yanıt yok = gecikme. '
            'Baş 25° sağa-sola, 22° aşağı-yukarı dönerse ya da yüz görünmezse odak dışı sayılır.',
            style: TextStyle(fontSize: 12.5, color: kMuted, height: 1.4)),
        const SizedBox(height: 12),
        const Text('Önerilerin yanındaki kitap simgesine dokunarak bilimsel kaynağı görebilirsin.',
            style: TextStyle(fontSize: 12.5, color: kMuted)),
      ]),
    );
  }
}

/// Kullanılan seviye bilgisini dışarıya da aç
String levelName(double s) => levelTitle(levelOf(s));
