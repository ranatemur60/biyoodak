import 'package:material_ui/material_ui.dart';

import '../services/screen_time.dart';
import '../services/storage.dart';
import '../widgets/common.dart';

/// Mola bildirimleri anahtarı (Ekran Kullanımım ve Ayarlar'da).
class BreakAlertsCard extends StatefulWidget {
  final VoidCallback? onChanged;
  const BreakAlertsCard({super.key, this.onChanged});
  @override
  State<BreakAlertsCard> createState() => _BreakAlertsCardState();
}

class _BreakAlertsCardState extends State<BreakAlertsCard> with WidgetsBindingObserver {
  ScreenStats? st;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (!ScreenTime.supported) return;
    final v = await ScreenTime.stats();
    if (mounted) setState(() => st = v);
  }

  Widget _warn(String text, String button, VoidCallback onTap) => Container(
        margin: const EdgeInsets.only(top: 10, right: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: const TextStyle(color: kRed, fontWeight: FontWeight.w600)),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onTap, child: Text(button))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      colors: gPurple,
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🔔', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Mola bildirimleri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kNavy))),
          Switch(
            value: Store.breakAlerts,
            onChanged: (v) async {
              Store.breakAlerts = v;
              if (v) {
                await ScreenTime.requestNotificationPermission();
                await ScreenTime.start(name: Store.profile.name, student: Store.profile.isStudent, exam: Store.profile.examName);
              } else {
                await ScreenTime.stop();
              }
              if (mounted) setState(() {});
              await Future<void>.delayed(const Duration(milliseconds: 300));
              await _load();
              widget.onChanged?.call();
            },
          ),
        ]),
        const SizedBox(height: 6),
        Text(
            ScreenTime.supported
                ? 'Telefonu kilidi açık şekilde kullandığın süre 30, 45 ve 60 dakikaya ulaşınca bildirim gelir. Ekran kapalıyken geçen süre sayılmaz. Telefon 30 dakika kapalı kalırsa sayaç sıfırlanır; daha kısa aralardan sonra kaldığı yerden devam eder.'
                : 'Web sürümünde yalnızca uygulama açıkken geçen süre sayılır; 30, 45 ve 60. dakikada uygulama içinde uyarı gösterilir.',
            style: const TextStyle(color: kNavy, height: 1.4)),
        if (ScreenTime.supported && Store.breakAlerts && st != null) ...[
          if (!st!.notifAllowed)
            _warn('Bildirim izni kapalı, bu yüzden uyarılar gelmez.', 'Bildirim iznini aç',
                () => ScreenTime.openNotifSettings()),
          if (st!.notifAllowed && !st!.batteryOk)
            _warn('Pil tasarrufu uygulamayı arka planda durdurabilir. Açılan listede NeuroVibe\'yı bulup "Optimize etme" seç.', 'Arka planda çalışmasına izin ver',
                () => ScreenTime.requestBattery()),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await ScreenTime.sendTest();
              await _load();
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Deneme bildirimi gönder'),
          ),
        ],
      ]),
    );
  }
}

class ScreenUsageScreen extends StatefulWidget {
  const ScreenUsageScreen({super.key});
  @override
  State<ScreenUsageScreen> createState() => _ScreenUsageScreenState();
}

class _ScreenUsageScreenState extends State<ScreenUsageScreen> {
  ScreenStats? s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await ScreenTime.stats();
    if (mounted) setState(() => s = v);
  }

  Widget _stat(String emoji, String label, String value, List<Color> bg) => GradientCard(
        colors: bg,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: kNavy))),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kNavy)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final st = s;
    final android = ScreenTime.supported;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Ekran Kullanımım', style: TextStyle(fontWeight: FontWeight.w800)),
          centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFE2F6FF), borderRadius: BorderRadius.circular(20)),
            child: Text(
                android
                    ? 'Bu bölüm telefonun kilidi açık ve ekranı açıkken geçen süreyi ölçer. Ekran kapalıyken veya kilit ekranındayken sayılmaz.'
                    : 'Tarayıcı telefonun genel ekran süresini okuyamaz. Burada yalnızca NeuroVibe açıkken geçen süre gösterilir. Telefon geneli takip Android sürümünde çalışır.',
                style: const TextStyle(color: kNavy, height: 1.4)),
          ),
          const SizedBox(height: 16),
          if (st == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else ...[
            _stat('📱', 'Bugünkü ekran süresi', '${st.todayMin} dk', gBlue),
            const SizedBox(height: 12),
            _stat('⏱️', 'Şu anki kullanım', android ? '${st.currentUseMin} dk' : '${WebUsage.sessionMin} dk', gOrange),
            if (android) ...[
              const SizedBox(height: 12),
              _stat('🌙', 'Dün gece (22:00-06:00)', '${st.nightMin} dk', gPurple),
              const SizedBox(height: 12),
              _stat('🔔', 'Gönderilen mola bildirimi', '${st.alertsSent}', gPink),
              if (st.notifLatenciesMs.isNotEmpty) ...[
                const SizedBox(height: 12),
                _stat('⚡', 'Son bildirime tepki', '${(st.notifLatenciesMs.last / 1000).toStringAsFixed(1)} sn', gGreen),
              ],
              if (Store.breakAlerts && !st.enabled) ...[
                const SizedBox(height: 12),
                const Text('Takip şu an çalışmıyor. Bildirim izni verdiğinden emin ol ve anahtarı kapatıp aç.',
                    style: TextStyle(color: kRed)),
              ],
            ],
          ],
          const SizedBox(height: 18),
          BreakAlertsCard(onChanged: _load),
          if (!android) ...[
            const SizedBox(height: 12),
            const Text(
                'iPhone\'da Ayarlar > Ekran Süresi > Uygulama Sınırları ile telefon geneli benzer bir uyarı kurabilirsin.',
                style: TextStyle(color: kMuted, fontSize: 13.5)),
          ],
        ]),
      ),
    );
  }
}
