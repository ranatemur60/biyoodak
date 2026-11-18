import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../analysis/scoring.dart';
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
    String two(int v) => v.toString().padLeft(2, '0');
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        const Expanded(
            child: Text('Geçmiş Ölçümler', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        IconButton(
          tooltip: 'CSV olarak kopyala',
          icon: const Icon(Icons.table_view_outlined),
          onPressed: h.isEmpty
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: historyToCsv(h)));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Tüm ölçümler CSV olarak kopyalandı. Excel veya E-Tablolar\'a yapıştırabilirsin.')));
                },
        ),
      ]),
      if (h.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: Text('Henüz ölçüm yok.')),
        )
      else ...[
        const SizedBox(height: 8),
        const Text('Bileşik gösterge eğilimi (eskiden yeniye)'),
        LineChart(y: h.reversed.map((m) => m.composite).toList(), hLine: 50, height: 100),
        const SizedBox(height: 8),
        const Text('Ortam koşullarına göre özet (Ek 3 tablosu için)',
            style: TextStyle(fontWeight: FontWeight.w600)),
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
        const SizedBox(height: 8),
        for (final m in h)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: levelColor(m.composite),
                child: Text('${m.composite.round()}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text(levelTitle(levelOf(m.composite))),
              subtitle: Text(
                  '${two(m.time.day)}.${two(m.time.month)}.${m.time.year} ${two(m.time.hour)}:${two(m.time.minute)} · Nabız: ${m.bpm?.round() ?? '-'} · PERCLOS %${m.perclos.toStringAsFixed(1)} · Güven %${m.confidence.round()}'),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => ResultScreen(m: m))),
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
    double avg(double Function(Measurement) f) =>
        l.map(f).reduce((a, b) => a + b) / l.length;
    out[cond] = {
      'n': l.length.toDouble(),
      'perclos': avg((m) => m.perclos),
      'pulseQ': avg((m) => m.pulseQ),
      'rt': avg((m) => m.reactionMedianMs ?? 0),
      'conf': avg((m) => m.confidence),
      'valid': 100 * l.where((m) => m.bpm != null).length / l.length,
    };
  }
  return out;
}
