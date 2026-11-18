import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'vision_stub.dart'
    if (dart.library.io) 'vision_android.dart'
    if (dart.library.js_interop) 'vision_web.dart' as impl;

/// Kameradan gelen tek bir örnek.
/// Renk örnekleri her karede, yüz yer işareti örnekleri yüz algılayıcı
/// her sonuç verdiğinde üretilir.
class FrameSample {
  final double tMs;
  // Alın ROI ortalama renkleri (renk örneği değilse null)
  final double? r, g, b;
  // Yüz yer işareti örneği mi?
  final bool isLandmark;
  final bool face;
  final double? earLeft, earRight;
  final double? yaw, pitch;

  const FrameSample.color(this.tMs, this.r, this.g, this.b)
      : isLandmark = false,
        face = true,
        earLeft = null,
        earRight = null,
        yaw = null,
        pitch = null;

  const FrameSample.landmark(this.tMs,
      {required this.face, this.earLeft, this.earRight, this.yaw, this.pitch})
      : isLandmark = true,
        r = null,
        g = null,
        b = null;

  double? get ear {
    if (earLeft == null && earRight == null) return null;
    if (earLeft == null) return earRight;
    if (earRight == null) return earLeft;
    return (earLeft! + earRight!) / 2;
  }

  /// Bakış ekseninden sapma (odak kaybı): yüz yok ya da baş belirgin dönük.
  bool get offFocus =>
      !face || (yaw != null && yaw!.abs() > 25) || (pitch != null && pitch!.abs() > 22);
}

/// Platforma göre kamera + yüz analizi kaynağı.
abstract class VisionSource {
  Stream<FrameSample> get samples;

  /// Kamerayı başlatır. Hata durumunda Türkçe bir mesajla istisna fırlatır.
  Future<void> start();
  Future<void> stop();

  /// Kamera önizleme bileşeni (start sonrası).
  Widget preview();

  static VisionSource create() => impl.createVisionSource();
}
