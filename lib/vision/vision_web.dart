import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import 'vision_source.dart';

VisionSource createVisionSource() => WebVisionSource();

extension type _Sample(JSObject o) implements JSObject {
  external int get k;
  external double get t;
  external double? get r;
  external double? get g;
  external double? get b;
  external bool? get face;
  external double? get el;
  external double? get er;
  external double? get yaw;
  external double? get pitch;
}

extension type _BiyoVision(JSObject o) implements JSObject {
  external JSPromise<JSAny?> start(web.HTMLVideoElement v, JSFunction cb);
  external void stop();
  external void preload();
}

@JS('biyoVision')
external _BiyoVision? get _biyoVision;

/// Web (iPhone Safari dahil): tarayıcı kamerası + MediaPipe Face Landmarker.
class WebVisionSource implements VisionSource {
  static bool _registered = false;
  static final web.HTMLVideoElement _video = web.HTMLVideoElement()
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'cover'
    ..style.transform = 'scaleX(-1)';

  final _ctrl = StreamController<FrameSample>.broadcast();

  WebVisionSource() {
    if (!_registered) {
      _registered = true;
      ui_web.platformViewRegistry
          .registerViewFactory('biyo-video', (int id) => _video);
    }
  }

  @override
  Stream<FrameSample> get samples => _ctrl.stream;

  Future<_BiyoVision> _api() async {
    for (var i = 0; i < 100; i++) {
      final a = _biyoVision;
      if (a != null) return a;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw Exception('Yüz analizi modülü yüklenemedi.');
  }

  @override
  Future<void> start() async {
    final api = await _api();
    void onSample(JSObject o) {
      final s = _Sample(o);
      if (s.k == 0) {
        _ctrl.add(FrameSample.color(s.t, s.r, s.g, s.b));
      } else {
        _ctrl.add(FrameSample.landmark(s.t,
            face: s.face ?? false,
            earLeft: s.el,
            earRight: s.er,
            yaw: s.yaw,
            pitch: s.pitch));
      }
    }

    try {
      await api.start(_video, onSample.toJS).toDart;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('NotAllowed') || msg.contains('Permission')) {
        throw Exception(
            'Kamera izni verilmedi. Tarayıcı ayarlarından kamera iznini açın.');
      }
      throw Exception('Kamera başlatılamadı: $msg');
    }
  }

  @override
  Future<void> stop() async {
    _biyoVision?.stop();
  }

  @override
  Widget preview() => const HtmlElementView(viewType: 'biyo-video');

  static void preload() => _biyoVision?.preload();
}
