import '../analysis/scoring.dart';
import '../models.dart';

/// Bilimsel kaynak bilgisi.
class Source {
  final String citation;
  final String doi;
  final String note;
  const Source(this.citation, this.doi, this.note);
  String get url => 'https://doi.org/$doi';
}

class Sources {
  static const reaction = Source(
      'Woods, D. L. ve arkadaşları (2015). Factors influencing the latency of simple reaction time. Frontiers in Human Neuroscience, 9, 131.',
      '10.3389/fnhum.2015.00131',
      'Yaklaşık 200-250 ms, basit görsel tepki süresi araştırmalarında dikkat çeken genel bir karşılaştırma düzeyidir; bu çalışmadan türetilmiş bir tanı eşiği değildir. Telefonda ölçülen değerler ekran ve dokunma gecikmesi nedeniyle daha yüksek olabilir.');
  static const eReader = Source(
      'Chang, A. M., Aeschbach, D., Duffy, J. F., & Czeisler, C. A. (2015). Evening use of light-emitting eReaders negatively affects sleep, circadian timing, and next-morning alertness. PNAS, 112(4), 1232-1237.',
      '10.1073/pnas.1418490112',
      'Yatmadan önce ışık yayan ekran kullanımı melatonin salınımını baskılamış, uykuya dalmayı geciktirmiş ve ertesi sabah uyanıklığı azaltmıştır.');
  static const led = Source(
      'Cajochen, C. ve arkadaşları (2011). Evening exposure to LED-backlit screens affects circadian physiology and cognitive performance. Journal of Applied Physiology, 110(5), 1432-1438.',
      '10.1152/japplphysiol.00165.2011',
      'Akşam LED arka aydınlatmalı ekran kullanımı melatonini baskılamış ve bilişsel performansı etkilemiştir.');
  static const roomLight = Source(
      'Gooley, J. J. ve arkadaşları (2011). Exposure to room light before bedtime suppresses melatonin onset and shortens melatonin duration in humans. J Clin Endocrinol Metab, 96(3), E463-E472.',
      '10.1210/jc.2010-2098',
      'Uygulamadaki melatonin tahmini bu tür çalışmalardan esinlenen teorik bir modeldir; melatonin doğrudan ölçülmez.');
  static const sleepTeen = Source(
      'Paruthi, S. ve arkadaşları (2016). Recommended amount of sleep for pediatric populations. Journal of Clinical Sleep Medicine, 12(6), 785-786.',
      '10.5664/jcsm.5866',
      '13-18 yaş için düzenli olarak gecede 8-10 saat uyku önerilmektedir.');
  static const water = Source(
      'EFSA Panel on Dietetic Products, Nutrition and Allergies (2010). Scientific Opinion on Dietary reference values for water. EFSA Journal, 8(3), 1459.',
      '10.2903/j.efsa.2010.1459',
      'Günlük toplam su alımı için genel referans değerler verir (yiyeceklerle alınan su dahil). Kişisel ihtiyaç aktivite ve iklime göre değişir.');
  static const eyeStrain = Source(
      'Sheppard, A. L., & Wolffsohn, J. S. (2018). Digital eye strain: prevalence, measurement and amelioration. BMJ Open Ophthalmology, 3(1), e000146.',
      '10.1136/bmjophth-2018-000146',
      'Dijital göz yorgunluğunu azaltmak için düzenli molalar ve 20-20-20 kuralı (20 dakikada bir, 20 saniye, ~6 metre uzağa bakmak) önerilmektedir.');
  static const breathing = Source(
      'Ma, X. ve arkadaşları (2017). The effect of diaphragmatic breathing on attention, negative affect and stress in healthy adults. Frontiers in Psychology, 8, 874.',
      '10.3389/fpsyg.2017.00874',
      'Diyafram nefesi uygulamasının dikkat ve stres göstergeleri üzerinde olumlu etkileri bildirilmiştir.');
  static const perclos = Source(
      'Wierwille, W. W., & Ellsworth, L. A. (1994). Evaluation of driver fatigue and drowsiness measures. Human Factors, 36(1), 71-87.',
      '10.1177/001872089403600106',
      'PERCLOS (göz kapağı kapanma yüzdesi) yorgunluk göstergesi olarak kullanılmaktadır.');
  static const rppg = Source(
      'Verkruysse, W., Svaasand, L. O., & Nelson, J. S. (2008). Remote plethysmographic imaging using ambient light. Optics Express, 16(26), 21434-21445.',
      '10.1364/OE.16.021434',
      'Sıradan bir kamerayla yüzdeki renk değişimlerinden nabız sinyali elde edilebileceğini göstermiştir. En güçlü sinyal yeşil kanaldadır.');
  static const snr = Source(
      'de Haan, G., & Jeanne, V. (2013). Robust pulse rate from chrominance-based rPPG. IEEE Transactions on Biomedical Engineering, 60(10), 2878-2886.',
      '10.1109/TBME.2013.2266196',
      'Uygulamadaki SNR (sinyal-gürültü oranı) hesabı bu çalışmadaki tanıma dayanır.');
  static const pvt = Source(
      'Dinges, D. F., & Powell, J. W. (1985). Microcomputer analyses of performance on a portable, simple visual RT task during sustained operations. Behavior Research Methods, Instruments, & Computers, 17(6), 652-655.',
      '10.3758/BF03200977',
      'Psikomotor uyanıklık testi (PVT): rastgele aralıklarla gelen uyarana tepki süresi; 500 ms üzeri yanıtlar "gecikme" (lapse) sayılır.');
}

class Advice {
  final String icon;
  final String text;
  final String? reason;
  final Source? source;
  const Advice(this.icon, this.text, {this.reason, this.source});
}

/// Rapordaki sabit "Genel Öneriler" listesi.
const generalAdvice = <Advice>[
  Advice('👀', 'Uzun ekran kullanımında düzenli ara verin.', source: Sources.eyeStrain),
  Advice('💧', 'Gün boyunca yeterli su tüketin.', source: Sources.water),
  Advice('🌙', 'Mümkün olduğunca düzenli saatlerde uyuyup uyanın.', source: Sources.sleepTeen),
  Advice('👁️', 'Ekran başındayken ara sıra uzağa bakarak gözlerinizi dinlendirin.', source: Sources.eyeStrain),
  Advice('🚶', 'Uzun süre oturduysanız kısa bir hareket molası verebilirsiniz.'),
  Advice('🌿', 'Yoğun bir günün ardından birkaç dakika kendinize zaman ayırın.', source: Sources.breathing),
  Advice('☀️', 'Gün içinde uygun olduğunda doğal gün ışığından yararlanın.'),
  Advice('🔕', 'Odaklanmak istediğinizde gereksiz bildirimleri sessize alabilirsiniz.'),
];

/// Ölçüm sonucu ve ilk açılışta yanıtlanan sorulara göre kişisel öneriler.
List<Advice> smartAdvice(Measurement m, UserProfile u) {
  final out = <Advice>[];
  final level = levelOf(m.composite);

  // Akıllı mola önerisi (nedeniyle birlikte)
  final reasons = <String>[];
  if (m.notifReactionMs == null || m.notifReactionMs! > 1500) {
    reasons.add('bildirim tepki süresi yavaş');
  }
  if (m.perclos > 10) reasons.add('göz kapanma oranı (PERCLOS) yüksek');
  if ((m.reactionMedianMs ?? 0) > 450) reasons.add('reaksiyon süresi uzamış');
  if (m.offFocusPct > 20) reasons.add('bakış sık sık ekrandan kaymış');
  if (level == FocusLevel.severe) {
    out.add(Advice('🛑', '20 dakika ekran molası önerilir.',
        reason: reasons.isEmpty ? 'bileşik gösterge düşük' : reasons.join(', '),
        source: Sources.pvt));
  } else if (level == FocusLevel.mild || reasons.isNotEmpty) {
    out.add(Advice('⏸️', '10 dakika ekran molası önerilir.',
        reason: reasons.isEmpty ? 'hafif yorgunluk belirtisi' : reasons.join(', '),
        source: Sources.reaction));
  } else {
    out.add(const Advice('✅',
        'Odağın iyi görünüyor. 25-30 dakikalık çalışma bloklarının ardından kısa mola vermeye devam et.',
        source: Sources.eyeStrain));
  }

  if (m.perclos > 8 || m.blinkRate < 6) {
    out.add(const Advice('👁️',
        '20-20-20 kuralı: 20 dakikada bir, 20 saniye boyunca 6 metre uzağa bak.',
        reason: 'göz yorgunluğu belirtisi', source: Sources.eyeStrain));
  }

  final targetMl = (u.weightKg * 33).clamp(1500, 3000).round();
  final drinkMl = u.waterGlasses * 200;
  if (drinkMl < targetMl * 0.8) {
    final glasses = (targetMl / 200).round();
    out.add(Advice('💧',
        'Günde yaklaşık $targetMl ml (≈$glasses bardak) sıvı hedefle. Şu an yaklaşık ${u.waterGlasses} bardak içtiğini belirttin; şimdi bir bardak su iç.',
        reason: 'genel sağlık önerisi (kiloya göre yaklaşık değer)',
        source: Sources.water));
  }

  if (u.nightVideo >= 2 || m.circadianExposure >= 33) {
    out.add(const Advice('📵',
        'Yatmadan en az 1 saat önce kısa video izlemeyi bırak; telefonu yatağın dışında şarj et.',
        reason: 'gece ekran maruziyeti', source: Sources.eReader));
  }
  if (u.sleepHours < 8) {
    out.add(Advice('🌙',
        'Yaşına göre gecede 8-10 saat uyku önerilir. Şu an ortalama ${u.sleepHours.toStringAsFixed(1)} saat uyuduğunu belirttin.',
        reason: 'uyku süresi', source: Sources.sleepTeen));
  }
  if (m.stress == 'Yüksek' || m.stress == 'Orta') {
    out.add(const Advice('🌬️',
        '2 dakika diyafram nefesi: 4 saniye burnundan al, 6 saniye ağzından ver.',
        reason: 'nabız temel değerinin üzerinde', source: Sources.breathing));
  }
  if (u.activity == 0) {
    out.add(const Advice('🚶',
        'Her ders saatinin sonunda 3-5 dakika ayağa kalk, yürü ve esne.',
        reason: 'düşük fiziksel aktivite'));
  }
  if (u.caffeine >= 3 || (u.caffeine >= 1 && DateTime.now().hour >= 16)) {
    out.add(const Advice('☕',
        'Saat 16:00\'dan sonra çay/kahve tüketimini azalt; uykuya geçişi geciktirebilir.',
        reason: 'kafein alımı'));
  }
  if (u.phoneNearWhileStudy && m.offFocusPct > 10) {
    out.add(const Advice('🔕',
        'Ders çalışırken telefonu başka odaya koy ya da Odak/Rahatsız Etmeyin modunu aç.',
        reason: 'odak kaybı'));
  }
  if (m.subjectiveFatigue >= 7) {
    out.add(const Advice('🧘',
        'Kendini yorgun hissediyorsun: kısa bir mola, su ve temiz hava iyi gelebilir.',
        reason: 'öznel yorgunluk yüksek'));
  }
  return out;
}
