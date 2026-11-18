import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../services/screen_time.dart';
import '../services/storage.dart';

/// İlk açılışta (ve Ayarlar'dan) yanıtlanan alışkanlık soruları.
/// Bu yanıtlar Akıllı Öneriler'i kullanıcıya özgü hale getirir.
class ProfileForm extends StatefulWidget {
  final bool firstRun;
  final VoidCallback? onDone;
  const ProfileForm({super.key, this.firstRun = false, this.onDone});
  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late UserProfile u = Store.profile;
  bool accepted = false;
  late final _name = TextEditingController(text: u.name);

  Widget _q(String title, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          child,
        ]),
      );

  Widget _slider(double v, double min, double max, int div, String label,
          ValueChanged<double> on) =>
      Row(children: [
        Expanded(
            child: Slider(
                value: v.clamp(min, max),
                min: min,
                max: max,
                divisions: div,
                label: label,
                onChanged: on)),
        SizedBox(width: 72, child: Text(label, textAlign: TextAlign.end)),
      ]);

  Widget _choice(List<String> opts, int value, ValueChanged<int> on) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < opts.length; i++)
            ChoiceChip(
                label: Text(opts[i]),
                selected: value == i,
                onSelected: (_) => setState(() => on(i))),
        ],
      );

  Future<void> _save() async {
    u.name = _name.text.trim();
    await Store.saveProfile(u);
    if (widget.firstRun) {
      Store.onboarded = true;
      await ScreenTime.requestNotificationPermission();
      if (Store.breakAlerts) await ScreenTime.start(name: u.name);
    }
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (widget.firstRun) ...[
        Text('BiyoOdak\'a hoş geldin 👋',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
            'Bu uygulama ön kamerayla göz kırpma (PERCLOS), temassız nabız (rPPG) ve tepki süresini ölçerek bilişsel yorgunluk ve odaklanma durumunu renkli bir göstergeyle sunar. Önerileri sana özel hale getirmek için birkaç soruyu yanıtla. Bu sorular yalnızca bir kez sorulur.'),
        const SizedBox(height: 8),
      ],
      _q('Adın (isteğe bağlı)', TextField(controller: _name, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true))),
      _q('Yaşın', _slider(u.age.toDouble(), 10, 60, 50, '${u.age}', (v) => setState(() => u.age = v.round()))),
      _q('Kilon (su önerisi için)', _slider(u.weightKg, 30, 120, 90, '${u.weightKg.round()} kg', (v) => setState(() => u.weightKg = v.roundToDouble()))),
      _q('Günde kaç bardak su içiyorsun?', _slider(u.waterGlasses.toDouble(), 0, 15, 15, '${u.waterGlasses} bardak', (v) => setState(() => u.waterGlasses = v.round()))),
      _q('Ortalama kaç saat uyuyorsun?', _slider(u.sleepHours, 3, 12, 18, '${u.sleepHours.toStringAsFixed(1)} sa', (v) => setState(() => u.sleepHours = v))),
      _q('Genelde saat kaçta yatıyorsun?', _choice(const ['21:30', '22:30', '23:30', '00:30', '01:30+'], const ['21:30', '22:30', '23:30', '00:30', '01:30'].indexOf(u.bedTime).clamp(0, 4), (i) => u.bedTime = const ['21:30', '22:30', '23:30', '00:30', '01:30'][i])),
      _q('Gece yatağa girdikten sonra ne kadar kısa video (Reels/TikTok/Shorts) izliyorsun?', _choice(const ['Hiç', '1-30 dk', '31-60 dk', '1-2 saat', '2+ saat'], u.nightVideo, (i) => u.nightVideo = i)),
      _q('Günlük fiziksel aktiviten', _choice(const ['Az', 'Orta', 'Çok'], u.activity, (i) => u.activity = i)),
      _q('Günde kaç bardak çay/kahve/enerji içeceği?', _slider(u.caffeine.toDouble(), 0, 8, 8, '${u.caffeine}', (v) => setState(() => u.caffeine = v.round()))),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ders çalışırken telefonum yanımda olur'),
          value: u.phoneNearWhileStudy,
          onChanged: (v) => setState(() => u.phoneNearWhileStudy = v)),
      if (widget.firstRun) ...[
        const Divider(),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: accepted,
          onChanged: (v) => setState(() => accepted = v ?? false),
          title: const Text(
              'Bu uygulamanın bir araştırma prototipi olduğunu, tıbbi tanı koymadığını ve profesyonel tıbbi değerlendirmenin yerine geçmediğini anladım. Kamera görüntüleri kaydedilmez ve hiçbir sunucuya gönderilmez; tüm veriler cihazımda kalır.'),
        ),
      ],
      const SizedBox(height: 12),
      FilledButton(
          onPressed: (!widget.firstRun || accepted) ? _save : null,
          child: Text(widget.firstRun ? 'Başla' : 'Kaydet')),
    ]);
  }
}
