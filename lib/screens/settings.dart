import 'package:material_ui/material_ui.dart';

import '../services/recommendations.dart';
import '../services/session.dart';
import '../services/storage.dart';
import '../widgets/common.dart';
import 'profile_form.dart';
import 'screen_usage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Widget _item(IconData icon, String title, {String? sub, VoidCallback? onTap, Color color = kNavy}) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: const Color(0xFFF6F4FB), borderRadius: BorderRadius.circular(20)),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          leading: Icon(icon, color: color),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          subtitle: sub == null ? null : Text(sub),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );

  Widget _about(String emoji, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: kNavy, height: 1.4))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final name = Store.profile.name.trim();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      const Text('Ayarlar', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kNavy)),
      const SizedBox(height: 16),
      GradientCard(
        colors: gHeader,
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('🧠', style: TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'Araştırma Kullanıcısı' : name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text(name.isEmpty ? 'NeuroVibe prototip' : 'Araştırma Kullanıcısı',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      BreakAlertsCard(onChanged: () => setState(() {})),
      const SizedBox(height: 16),
      _item(Icons.person_outline, 'Alışkanlık sorularını düzenle',
          sub: 'Akıllı öneriler bu cevaplara göre hazırlanır',
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (ctx) => Scaffold(
                      appBar: AppBar(title: const Text('Profil')),
                      body: ProfileForm(onDone: () {
                        Navigator.pop(ctx);
                        setState(() {});
                      }))))),
      _item(Icons.smartphone, 'Ekran Kullanımım',
          onTap: () => Navigator.push(
              context, MaterialPageRoute<void>(builder: (_) => const ScreenUsageScreen()))),
      _item(Icons.menu_book_outlined, 'Bilimsel Kaynaklar',
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _SourcesScreen()))),
      _item(Icons.delete_outline, 'Tüm karneleri sil', color: kRed, onTap: () async {
        final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                  title: const Text('Karneler silinsin mi?'),
                  content: const Text('Bu işlem geri alınamaz.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
                  ],
                ));
        if (ok == true) {
          await Store.clearHistory();
          CurrentSession.reset();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Karneler silindi')));
          }
        }
      }),
      const SizedBox(height: 14),
      const Text('Uygulama Hakkında', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kNavy)),
      const SizedBox(height: 8),
      _about('🔬', 'Bilişsel Yorgunluk Karnesi • Prototip sürüm\nTÜBİTAK 2204-A Lise Öğrencileri Araştırma Projeleri'),
      _about('📱', 'Ölçümler ön kamerayla yapılır. Görüntü kaydedilmez ve hiçbir sunucuya gönderilmez; analiz cihaz üzerinde anlık yapılır.'),
      _about('🛡️', 'Bu uygulama tıbbi tanı aracı değildir.'),
    ]);
  }
}

class _SourcesScreen extends StatelessWidget {
  const _SourcesScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bilimsel Kaynaklar')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final src in const [
            Sources.perclos, Sources.rppg, Sources.snr, Sources.pvt, Sources.reaction,
            Sources.eReader, Sources.led, Sources.roomLight, Sources.sleepTeen,
            Sources.water, Sources.eyeStrain, Sources.breathing,
          ])
            ListTile(
              leading: const Icon(Icons.menu_book_outlined, color: kPrimary),
              title: Text(src.citation, maxLines: 3, overflow: TextOverflow.ellipsis),
              onTap: () => showSource(context, src),
            ),
        ]),
      );
}
