import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../analysis/scoring.dart';
import '../services/recommendations.dart';

const kGreen = Color(0xFF22B573);
const kYellow = Color(0xFFF2B518);
const kRed = Color(0xFFE5484D);
const kPrimary = Color(0xFF7B4FF5);
const kNavy = Color(0xFF1E1B3A);
const kPink = Color(0xFFE8467C);
const kTeal = Color(0xFF14C4B8);
const kOrange = Color(0xFFF5A524);
const kMuted = Color(0xFF6B6880);

/// NeuroVibe pastel kart renkleri (gradyan başlangıç-bitiş).
const gPink = [Color(0xFFFFE1EB), Color(0xFFFFF0F5)];
const gBlue = [Color(0xFFD3F3FF), Color(0xFFEAFBFF)];
const gOrange = [Color(0xFFFFE6BF), Color(0xFFFFF6E6)];
const gGreen = [Color(0xFFD4F9E6), Color(0xFFEAFBF5)];
const gPurple = [Color(0xFFEAE4FF), Color(0xFFF3EFFF)];
const gMint = [Color(0xFFD5FBEF), Color(0xFFE4F6FD)];
const gHero = [Color(0xFFF1E8FF), Color(0xFFFFE8F1), Color(0xFFE2F6FF)];
const gHeader = [Color(0xFF7B4FF5), Color(0xFFB062F0), Color(0xFFF77AA7)];

/// Yuvarlak köşeli, gradyan arka planlı kart.
class GradientCard extends StatelessWidget {
  final List<Color> colors;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  const GradientCard(
      {super.key,
      required this.colors,
      required this.child,
      this.onTap,
      this.padding = const EdgeInsets.all(20),
      this.radius = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
            colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: colors.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Ana sayfa / Ölçüm Merkezi modül kartı.
class ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
  const ModuleCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.colors,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GradientCard(
        colors: colors,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 34, color: kNavy),
          const SizedBox(height: 18),
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: kNavy)),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: kMuted)),
        ]),
      );
}

/// Karne metrik kutusu (Nabız, PERCLOS, Tepki Süresi, Odaklanma).
class MetricTile extends StatelessWidget {
  final String label;
  final String? value; // null → Tamamlanmadı
  final Color color;
  final List<Color> bg;
  const MetricTile(
      {super.key,
      required this.label,
      required this.value,
      required this.color,
      required this.bg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: bg),
            borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: kNavy, fontSize: 15)),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value ?? 'Tamamlanmadı',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: value == null ? 15 : 26)),
          ),
        ]),
      );
}

/// NeuroVibe kalp ritmi çizgisi.
class EcgLine extends StatelessWidget {
  final double width;
  const EcgLine({super.key, this.width = 220});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width, height: 30, child: CustomPaint(painter: _EcgPainter()));
}

class _EcgPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = kPrimary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(0, s.height * 0.6);
    final seg = s.width / 3;
    for (var i = 0; i < 3; i++) {
      final x = i * seg + seg * 0.12;
      path
        ..lineTo(x, s.height * 0.6)
        ..lineTo(x + 6, s.height * 0.05)
        ..lineTo(x + 12, s.height * 0.95)
        ..lineTo(x + 18, s.height * 0.6);
    }
    path.lineTo(s.width, s.height * 0.6);
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

Color levelColor(double score) => switch (levelOf(score)) {
      FocusLevel.high => kGreen,
      FocusLevel.mild => kYellow,
      FocusLevel.severe => kRed,
    };

/// "Araştırma prototipi • Tıbbi tanı amacı taşımaz." uyarı şeridi.
class DisclaimerBar extends StatelessWidget {
  const DisclaimerBar({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text('Araştırma prototipi • Tıbbi tanı amacı taşımaz.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall),
      );
}

/// Renkli dairesel gösterge (Bilişsel Yorgunluk ve Odaklanma Göstergesi).
class FocusGauge extends StatelessWidget {
  final double score;
  final double size;
  const FocusGauge({super.key, required this.score, this.size = 200});

  @override
  Widget build(BuildContext context) {
    final c = levelColor(score);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(score / 100, c,
            Theme.of(context).colorScheme.surfaceContainerHighest),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('%${score.round()}',
                style: TextStyle(
                    fontSize: size * 0.22, fontWeight: FontWeight.bold, color: c)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.12),
              child: Text(levelTitle(levelOf(score)),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: size * 0.07, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double v;
  final Color c, bg;
  _GaugePainter(this.v, this.c, this.bg);
  @override
  void paint(Canvas canvas, Size s) {
    final stroke = s.width * 0.09;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(s.width - stroke, s.height - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5, false, p..color = bg);
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5 * v.clamp(0, 1), false,
        p..color = c);
  }

  @override
  bool shouldRepaint(_GaugePainter o) => o.v != v || o.c != c;
}

/// Renk skalası açıklaması.
class LevelLegend extends StatelessWidget {
  const LevelLegend({super.key});
  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(t, style: Theme.of(context).textTheme.labelSmall),
        ]);
    return Wrap(spacing: 12, runSpacing: 4, alignment: WrapAlignment.center, children: [
      item(kGreen, 'Yeşil %80-100 Yüksek Odak'),
      item(kYellow, 'Sarı %50-79 Hafif Yorgunluk'),
      item(kRed, 'Kırmızı %0-49 Yüksek Yorgunluk'),
    ]);
  }
}

/// Basit çizgi grafiği.
class LineChart extends StatelessWidget {
  final List<double> y;
  final List<double>? x;
  final Color color;
  final double? hLine;
  final String? hLineLabel;
  final double height;
  final int? markIndex;
  const LineChart(
      {super.key,
      required this.y,
      this.x,
      this.color = kPrimary,
      this.hLine,
      this.hLineLabel,
      this.height = 120,
      this.markIndex});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: y.length < 2
            ? const Center(child: Text('Veri yok'))
            : CustomPaint(
                painter: _LinePainter(y, color, hLine, hLineLabel, markIndex,
                    Theme.of(context).colorScheme.outlineVariant,
                    Theme.of(context).textTheme.labelSmall!)),
      );
}

class _LinePainter extends CustomPainter {
  final List<double> y;
  final Color c, grid;
  final double? h;
  final String? hl;
  final int? mark;
  final TextStyle ts;
  _LinePainter(this.y, this.c, this.h, this.hl, this.mark, this.grid, this.ts);
  @override
  void paint(Canvas canvas, Size s) {
    var lo = y.reduce(math.min), hi = y.reduce(math.max);
    if (h != null) {
      lo = math.min(lo, h!);
      hi = math.max(hi, h!);
    }
    if (hi - lo < 1e-9) hi = lo + 1;
    double py(double v) => s.height - 4 - (v - lo) / (hi - lo) * (s.height - 8);
    double px(int i) => i / (y.length - 1) * s.width;
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, s.height - 1), Offset(s.width, s.height - 1), g);
    if (h != null) {
      canvas.drawLine(Offset(0, py(h!)), Offset(s.width, py(h!)), g..color = kRed.withValues(alpha: 0.6));
      if (hl != null) {
        final tp = TextPainter(text: TextSpan(text: hl, style: ts.copyWith(color: kRed)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(4, py(h!) - tp.height));
      }
    }
    final path = Path()..moveTo(px(0), py(y[0]));
    for (var i = 1; i < y.length; i++) {
      path.lineTo(px(i), py(y[i]));
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    if (mark != null && mark! >= 0 && mark! < y.length) {
      canvas.drawCircle(Offset(px(mark!), py(y[mark!])), 4, Paint()..color = kRed);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// "Bilimsel Kaynak" penceresi.
void showSource(BuildContext context, Source s) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Bilimsel Kaynak'),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(s.citation),
          const SizedBox(height: 8),
          SelectableText('DOI: ${s.doi}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(s.note),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: s.url));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bağlantı kopyalandı')));
            },
            child: const Text('Bağlantıyı Kopyala')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
      ],
    ),
  );
}

class AdviceTile extends StatelessWidget {
  final Advice a;
  const AdviceTile(this.a, {super.key});
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Text(a.icon, style: const TextStyle(fontSize: 24)),
          title: Text(a.text, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: a.reason == null ? null : Text('Neden: ${a.reason}'),
          trailing: a.source == null
              ? null
              : IconButton(
                  tooltip: 'Bilimsel Kaynak',
                  icon: const Icon(Icons.menu_book_outlined),
                  onPressed: () => showSource(context, a.source!)),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.bold)),
      );
}

class KV extends StatelessWidget {
  final String k, v;
  const KV(this.k, this.v, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}
