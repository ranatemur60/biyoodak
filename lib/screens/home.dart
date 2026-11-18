import 'package:material_ui/material_ui.dart';

import '../main.dart';
import '../widgets/common.dart';
import 'measure.dart';
import 'screen_usage.dart';

class HomeScreen extends StatelessWidget {
  final MainShellState shell;
  const HomeScreen({super.key, required this.shell});

  Future<void> _open(BuildContext context, MeasureMode m) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MeasureScreen(mode: m)));
    shell.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), children: [
      Row(children: [
        const Expanded(
            child: Text('NeuroVibe',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: kNavy))),
        IconButton(
            onPressed: () => shell.go(3),
            icon: const Icon(Icons.settings_outlined, size: 30, color: kNavy)),
      ]),
      const SizedBox(height: 16),
      GradientCard(
        colors: gHero,
        child: Row(children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bugün kendine iyi bak! ✨',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: kNavy)),
              SizedBox(height: 10),
              Text('Göz, nabız ve dikkat ölçümlerini tek yerde takip et.',
                  style: TextStyle(fontSize: 15, height: 1.4, color: kNavy)),
            ]),
          ),
          const Text('🧠', style: TextStyle(fontSize: 64)),
        ]),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => _open(context, MeasureMode.full),
        icon: const Icon(Icons.play_circle_fill),
        label: const Text('Ölçüme Başla'),
      ),
      const SizedBox(height: 18),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.98,
        children: [
          ModuleCard(icon: Icons.favorite, title: 'Nabız Ölçümü', subtitle: 'Yüzden temassız • Deneysel', colors: gPink, onTap: () => _open(context, MeasureMode.pulse)),
          ModuleCard(icon: Icons.remove_red_eye, title: 'Göz Analizi', subtitle: 'Göz takibi', colors: gBlue, onTap: () => _open(context, MeasureMode.eye)),
          ModuleCard(icon: Icons.bolt, title: 'Tepki Hızı', subtitle: 'Tepki süresi', colors: gOrange, onTap: () => _open(context, MeasureMode.reaction)),
          ModuleCard(icon: Icons.auto_graph, title: 'Sonuçlarım', subtitle: 'Karnem', colors: gGreen, onTap: () => shell.go(2)),
        ],
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ScreenUsageScreen())),
        icon: const Icon(Icons.smartphone),
        label: const Text('Ekran Kullanımım'),
      ),
      const SizedBox(height: 16),
      const Center(
          child: Text('Araştırma prototipi • Tıbbi tanı amacı taşımaz.',
              style: TextStyle(color: kMuted, fontSize: 13))),
    ]);
  }
}
