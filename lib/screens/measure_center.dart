import 'package:material_ui/material_ui.dart';

import '../main.dart';
import '../widgets/common.dart';
import 'measure.dart';

class MeasureCenterScreen extends StatelessWidget {
  final MainShellState shell;
  const MeasureCenterScreen({super.key, required this.shell});

  Future<void> _open(BuildContext context, MeasureMode m) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MeasureScreen(mode: m)));
    shell.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => shell.go(0),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Ana Sayfaya Dön', style: TextStyle(fontSize: 17)),
        ),
      ),
      const SizedBox(height: 8),
      GradientCard(
        colors: gHeader,
        padding: const EdgeInsets.fromLTRB(24, 28, 20, 28),
        child: Row(children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ölçüm Merkezi',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
              SizedBox(height: 10),
              Text('Kendine birkaç dakika ayır, dilediğin ölçümle başla.',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 38),
          ),
        ]),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(8, 12, 8, 16),
        child: Text('Nabız için ön kamerayla temassız ölçüm kullanılır.',
            style: TextStyle(color: kMuted, fontSize: 14)),
      ),
      ModuleCard(icon: Icons.all_inclusive, title: 'Tam Ölçüm (45 sn)', subtitle: 'Göz • Nabız • Dikkat birlikte', colors: gPurple, onTap: () => _open(context, MeasureMode.full)),
      const SizedBox(height: 16),
      ModuleCard(icon: Icons.favorite, title: 'Nabız Ölçümü', subtitle: 'Yüzden temassız • Deneysel', colors: gPink, onTap: () => _open(context, MeasureMode.pulse)),
      const SizedBox(height: 16),
      ModuleCard(icon: Icons.remove_red_eye, title: 'Göz Analizi', subtitle: 'PERCLOS • Göz takibi', colors: gBlue, onTap: () => _open(context, MeasureMode.eye)),
      const SizedBox(height: 16),
      ModuleCard(icon: Icons.bolt, title: 'Tepki Hızı', subtitle: 'Dokunma tepki süresi', colors: gOrange, onTap: () => _open(context, MeasureMode.reaction)),
    ]);
  }
}
