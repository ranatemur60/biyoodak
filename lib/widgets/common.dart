import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../analysis/scoring.dart';
import '../services/recommendations.dart';

const kGreen = Color(0xFF2E9E5B);
const kYellow = Color(0xFFE8B10C);
const kRed = Color(0xFFD64545);
const kPrimary = Color(0xFF4F46E5);

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
