# NeuroVibe

**Gece Ekran Maruziyeti ile Bilişsel Yorgunluk İlişkisinin İncelenmesi ve Temassız Biyometrik Karar Destek Sistemi**
TÜBİTAK 2204-A Lise Öğrencileri Araştırma Projeleri

> Araştırma prototipidir. Sistem tıbbi tanı koyma amacı taşımaz; çıktılar profesyonel tıbbi değerlendirmenin yerine geçmez.

## Uygulamaya erişim

- **Android (tüm özellikler):** [NeuroVibe APK indir](https://github.com/ranatemur60/biyoodak/raw/gh-pages/NeuroVibe.apk)
  Kurulumda telefon "bilinmeyen uygulama" uyarısı verirse Ayarlar'dan izin verip "Yükle"ye basın.
- **iPhone / bilgisayar (web sürümü):** https://ranatemur60.github.io/biyoodak/
  Safari'de açıp Paylaş > "Ana Ekrana Ekle" ile uygulama gibi kullanılabilir. Web sürümünde telefon geneli ekran süresi bildirimleri yoktur (iOS kısıtı).

## Özellikler

- **Göz kırpma analizi (PERCLOS):** Yüz işaret noktalarından EAR = (‖p2−p6‖ + ‖p3−p5‖) / (2‖p1−p4‖); kişisel dinamik kalibrasyon (açık göz EAR'ın %60'ı kapalı eşik).
- **Temassız nabız (rPPG):** Alın ROI yeşil kanal ortalaması C(t) → trend giderme → 0.7–3.5 Hz Butterworth bant geçiren → Hann pencereli Fourier güç spektrumu → BPM; SNR (de Haan & Jeanne 2013) ve RMSSD (yalnızca temiz sinyalde).
- **Reaksiyon ve bildirim tepki analizi:** 45 saniyelik ölçümde rastgele uyaranlar (PVT benzeri) ve bildirim kartı; bakış kayması (baş açısı) ile odak dışı süre.
- **Bilişsel Yorgunluk ve Odaklanma Göstergesi:** Yeşil %80–100 · Sarı %50–79 · Kırmızı %0–49. Gösterge = 0.4·Göz + 0.4·(0.7·Reaksiyon + 0.3·Odak) + 0.2·Nabız.
- **Ölçüm Güven Skoru:** Göz analizi, nabız sinyali, tepki hızı ve odaklanma kalite yüzdelerinin ortalaması.
- **Akıllı Mola Bildirimleri (Android):** Sürekli ekran kullanımında 30, 45 ve 60. dakikada uyarı; 30 dakikalık moladan sonra sıfırlama; gece (22:00–06:00) ekran süresi kaydı; bildirim tepki süresi.
- **Akıllı Öneriler:** İlk açılıştaki alışkanlık sorularına ve ölçüme göre kişisel öneriler; her öneride bilimsel kaynak.
- **Teknik Rapor:** Ham değerler, EAR ve PPG grafikleri, spektrum, formüller, teorik melatonin modeli M = M_bazal·e^(−k·L·t).
- **Geçmiş:** Ölçüm listesi, eğilim grafiği, ortam koşullarına göre özet (Ek 3) ve CSV dışa aktarma.

## Gizlilik

Kamera görüntüleri kaydedilmez ve hiçbir sunucuya gönderilmez; tüm analiz cihaz üzerinde yapılır. Ölçüm sonuçları yalnızca cihazda saklanır.

## Teknik

Flutter (Dart). Android: CameraX + Google ML Kit yüz algılama, Kotlin ön plan servisi. Web: MediaPipe Face Landmarker (WebAssembly).

Derleme: `flutter build apk --release` · `flutter build web --release --no-web-resources-cdn --base-href /biyoodak/`
