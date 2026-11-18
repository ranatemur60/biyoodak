import 'package:material_ui/material_ui.dart';

import '../services/recommendations.dart';
import '../services/screen_time.dart';
import '../services/storage.dart';
import '../widgets/common.dart';
import 'profile_form.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ScreenStats? stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ScreenTime.stats();
    if (mounted) setState(() => stats = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Ayarlar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SectionTitle('Akıllı Mola Bildirimleri'),
      if (ScreenTime.supported) ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ekran süresi uyarıları'),
          subtitle: const Text(
              'Telefonu sürekli kullandığında 30, 45 ve 60. dakikada uyarır. Ekran 30 dakika kapalı kalırsa (mola) sayaç sıfırlanır.'),
          value: Store.breakAlerts,
          onChanged: (v) async {
            Store.breakAlerts = v;
            if (v) {
              await ScreenTime.requestNotificationPermission();
              await ScreenTime.start(name: Store.profile.name);
            } else {
              await ScreenTime.stop();
            }
            await Future<void>.delayed(const Duration(milliseconds: 300));
            await _load();
          },
        ),
        if (s != null) ...[
          KV('Bugünkü ekran süresi', '${s.todayMin} dk'),
          KV('Şu anki sürekli kullanım', '${s.currentUseMin} dk'),
          KV('Son gece ekran süresi (22:00–06:00)', '${s.nightMin} dk'),
          if (s.notifLatenciesMs.isNotEmpty)
            KV('Son bildirim tepki süresi', '${(s.notifLatenciesMs.last / 1000).toStringAsFixed(1)} sn'),
        ],
      ] else
        const Text(
            'Web sürümünde tarayıcı, telefonun genel ekran süresini okuyamaz. Bu yüzden yalnızca uygulama açıkken geçen süre sayılır ve 30/45/60. dakikalarda uygulama içinde uyarı gösterilir. Telefon geneli bildirimler Android sürümünde çalışır. iPhone\'da Ayarlar > Ekran Süresi > Uygulama Sınırları ile benzer bir uyarı kurabilirsin.'),
      const SectionTitle('Profil (Akıllı Öneriler)'),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_outline),
        title: const Text('Alışkanlık sorularını düzenle'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (ctx) => Scaffold(
                    appBar: AppBar(title: const Text('Profil')),
                    body: ProfileForm(onDone: () => Navigator.pop(ctx))))),
      ),
      const SectionTitle('Veri ve Gizlilik'),
      const Text(
          'Kamera görüntüleri kaydedilmez ve hiçbir sunucuya gönderilmez; analiz cihaz üzerinde anlık yapılır. Ölçüm sonuçları yalnızca bu cihazda saklanır.'),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.delete_outline),
        label: const Text('Tüm ölçüm geçmişini sil'),
        onPressed: () async {
          final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                    title: const Text('Geçmiş silinsin mi?'),
                    content: const Text('Bu işlem geri alınamaz.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
                    ],
                  ));
          if (ok == true) {
            await Store.clearHistory();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçmiş silindi')));
            }
          }
        },
      ),
      const SectionTitle('Bilimsel Kaynaklar'),
      for (final src in const [
        Sources.perclos, Sources.rppg, Sources.snr, Sources.pvt, Sources.reaction,
        Sources.eReader, Sources.led, Sources.roomLight, Sources.sleepTeen,
        Sources.water, Sources.eyeStrain, Sources.breathing,
      ])
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(src.citation, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => showSource(context, src),
        ),
      const SectionTitle('Hakkında'),
      const Text(
          'BiyoOdak · Gece Ekran Maruziyeti ve Temassız Biyometrik Karar Destek Sistemi\nTÜBİTAK 2204-A Lise Öğrencileri Araştırma Projeleri\n\nAraştırma prototipidir. Sistem tıbbi tanı koyma amacı taşımaz; çıktılar profesyonel tıbbi değerlendirmenin yerine geçmez.'),
      const SizedBox(height: 24),
    ]);
  }
}
