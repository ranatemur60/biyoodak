import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../services/recommendations.dart';
import '../services/screen_time.dart';
import '../services/storage.dart';
import '../widgets/common.dart';
import 'result.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onMeasure;
  const HomeScreen({super.key, required this.onMeasure});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ScreenStats? stats;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await ScreenTime.stats();
    if (mounted) setState(() => stats = s);
  }

  @override
  Widget build(BuildContext context) {
    final h = Store.history;
    final last = h.isEmpty ? null : h.first;
    final p = Store.profile;
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Günaydın' : (hour < 18 ? 'İyi günler' : 'İyi akşamlar');
    final tip = generalAdvice[DateTime.now().day % generalAdvice.length];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('$greet${p.name.isEmpty ? '' : ', ${p.name}'} 👋',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Bilişsel yorgunluğunu ve odağını 45 saniyede ölç.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('Bilişsel Yorgunluk ve Odaklanma Göstergesi',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (last == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Henüz ölçüm yok. İlk ölçümünü yap!', textAlign: TextAlign.center),
                )
              else
                InkWell(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute<void>(builder: (_) => ResultScreen(m: last))),
                  child: FocusGauge(score: last.composite, size: 180),
                ),
              const SizedBox(height: 8),
              const LevelLegend(),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onMeasure,
                icon: const Icon(Icons.favorite),
                label: const Text('Ölçüm Yap'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('📱 Ekran Süresi', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (stats == null)
                const LinearProgressIndicator()
              else if (stats!.supported) ...[
                KV('Bugün', '${stats!.todayMin} dk'),
                KV('Şu anki sürekli kullanım', '${stats!.currentUseMin} dk'),
                KV('Son gece (22:00–06:00)', '${stats!.nightMin} dk'),
                if (!stats!.enabled)
                  const Text('Mola bildirimleri kapalı. Ayarlar\'dan açabilirsin.'),
              ] else ...[
                KV('Bugün uygulamada', '${stats!.todayMin} dk'),
                const Text(
                    'Web sürümü yalnızca uygulama içindeki süreyi sayar. Telefon geneli takip Android sürümündedir.',
                    style: TextStyle(fontSize: 12)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Günün önerisi', style: TextStyle(fontWeight: FontWeight.bold)),
        AdviceTile(tip),
      ]),
    );
  }
}
