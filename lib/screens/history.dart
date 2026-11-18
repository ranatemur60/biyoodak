import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../services/storage.dart';
import '../widgets/common.dart';
import 'result.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final h = Store.history;
    final withScore = h.where((m) => m.hasIndicator).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      Row(children: [
        const Expanded(
            child: Text('Geçmiş Karnelerim',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kNavy))),
        IconButton(
          tooltip: 'CSV olarak kopyala',
          icon: const Icon(Icons.table_view_outlined, color: kNavy),
          onPressed: h.isEmpty
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: historyToCsv(h)));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Tüm ölçümler CSV olarak kopyalandı. Excel veya E-Tablolar\'a yapıştırabilirsin.')));
                },
        ),
      ]),
      const SizedBox(height: 4),
      const Text('Her karne aynı oturumda yapılan ölçümleri gösterir.',
          style: TextStyle(color: kMuted, fontSize: 15)),
      const SizedBox(height: 16),
      if (h.isEmpty)
        GradientCard(
          colors: gPurple,
          child: const Column(children: [
            Text('📋', style: TextStyle(fontSize: 44)),
            SizedBox(height: 8),
            Text('Henüz karne yok. İlk ölçümünü yaptığında burada görünecek.',
                textAlign: TextAlign.center, style: TextStyle(color: kNavy, fontSize: 15)),
          ]),
        )
      else ...[
        for (final m in h) ...[
          KarneCard(
              m: m,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => ResultScreen(m: m)))),
          const SizedBox(height: 12),
        ],
        if (withScore.length >= 2) ...[
          const SizedBox(height: 10),
          const Text('Yorgunluk göstergesi eğilimi (eskiden yeniye)',
              style: TextStyle(fontWeight: FontWeight.w800, color: kNavy, fontSize: 16)),
          const SizedBox(height: 6),
          LineChart(y: withScore.reversed.map((m) => m.composite).toList(), hLine: 50, height: 110),
        ],
        const SizedBox(height: 16),
        const Text('Ortam koşullarına göre özet (Ek 3 tablosu için)',
            style: TextStyle(fontWeight: FontWeight.w800, color: kNavy, fontSize: 16)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 14,
            columns: const [
              DataColumn(label: Text('Koşul')),
              DataColumn(label: Text('n')),
              DataColumn(label: Text('PERCLOS %')),
              DataColumn(label: Text('rPPG kalite')),
              DataColumn(label: Text('Reaksiyon ms')),
              DataColumn(label: Text('Güven')),
              DataColumn(label: Text('Geçerli nabız %')),
            ],
            rows: [
              for (final e in conditionSummary(h).entries)
                DataRow(cells: [
                  DataCell(Text(e.key)),
                  DataCell(Text(e.value['n']!.round().toString())),
                  DataCell(Text(e.value['perclos']!.toStringAsFixed(1))),
                  DataCell(Text(e.value['pulseQ']!.toStringAsFixed(0))),
                  DataCell(Text(e.value['rt']!.toStringAsFixed(0))),
                  DataCell(Text(e.value['conf']!.toStringAsFixed(0))),
                  DataCell(Text(e.value['valid']!.toStringAsFixed(0))),
                ]),
            ],
          ),
        ),
      ],
    ]);
  }
}

/// Ek 3 için ortam koşullarına göre ortalama tablo.
Map<String, Map<String, double>> conditionSummary(List<Measurement> h) {
  final out = <String, Map<String, double>>{};
  for (final cond in {for (final m in h) m.lightCondition}) {
    final l = h.where((m) => m.lightCondition == cond).toList();
    double avg(double Function(Measurement) f, [bool Function(Measurement)? use]) {
      final x = use == null ? l : l.where(use).toList();
      return x.isEmpty ? 0 : x.map(f).reduce((a, b) => a + b) / x.length;
    }
    out[cond] = {
      'n': l.length.toDouble(),
      'perclos': avg((m) => m.perclos, (m) => m.eyeDone),
      'pulseQ': avg((m) => m.pulseQ, (m) => m.pulseDone),
      'rt': avg((m) => m.reactionMedianMs ?? 0, (m) => m.reactionMedianMs != null),
      'conf': avg((m) => m.confidence),
      'valid': l.where((m) => m.pulseDone).isEmpty ? 0 : 100 * l.where((m) => m.bpm != null).length / l.where((m) => m.pulseDone).length,
    };
  }
  return out;
}
