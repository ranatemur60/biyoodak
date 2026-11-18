import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:material_ui/material_ui.dart';

import '../analysis/perclos.dart';
import 'vision_source.dart';

VisionSource createVisionSource() => AndroidVisionSource();

/// Android: CameraX görüntü akışı (NV21) + Google ML Kit yüz algılama.
class AndroidVisionSource implements VisionSource {
  CameraController? _controller;
  final _ctrl = StreamController<FrameSample>.broadcast();
  late final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.2,
    ),
  );
  bool _busy = false;
  // Alın ROI (ham görüntü koordinatlarında)
  Rect? _roiRaw;
  int _rotation = 270;
  final _sw = Stopwatch();

  @override
  Stream<FrameSample> get samples => _ctrl.stream;

  @override
  Future<void> start() async {
    final cams = await availableCameras();
    if (cams.isEmpty) throw Exception('Kamera bulunamadı.');
    final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first);
    _rotation = front.sensorOrientation;
    final c = CameraController(front, ResolutionPreset.medium,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
    try {
      await c.initialize();
    } on CameraException catch (e) {
      if (e.code.contains('Access')) {
        throw Exception('Kamera izni verilmedi. Ayarlardan kamera iznini açın.');
      }
      rethrow;
    }
    _controller = c;
    _sw
      ..reset()
      ..start();
    await c.startImageStream(_onFrame);
  }

  @override
  Future<void> stop() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      try {
        if (c.value.isStreamingImages) await c.stopImageStream();
      } catch (_) {}
      await c.dispose();
    }
  }

  @override
  Widget preview() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return CameraPreview(c);
  }

  void _onFrame(CameraImage img) {
    final t = _sw.elapsedMicroseconds / 1000.0;
    final plane = img.planes.first;
    final bytes = plane.bytes;
    final w = img.width, h = img.height;
    final roi = _roiRaw;
    if (roi != null) {
      final rgb = _roiMeanNv21(bytes, w, h, roi);
      if (rgb != null) _ctrl.add(FrameSample.color(t, rgb[0], rgb[1], rgb[2]));
    }
    if (!_busy) {
      _busy = true;
      _detect(Uint8List.fromList(bytes), w, h, t);
    }
  }

  Future<void> _detect(Uint8List bytes, int w, int h, double t) async {
    try {
      final input = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(w.toDouble(), h.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(_rotation) ??
              InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
          bytesPerRow: w,
        ),
      );
      final faces = await _detector.processImage(input);
      if (faces.isEmpty) {
        _roiRaw = null;
        _ctrl.add(FrameSample.landmark(t, face: false));
      } else {
        faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
            .compareTo(a.boundingBox.width * a.boundingBox.height));
        final f = faces.first;
        _roiRaw = _uprightToRaw(_foreheadRect(f), w, h);
        _ctrl.add(FrameSample.landmark(
          t,
          face: true,
          earLeft: _ear(f.contours[FaceContourType.leftEye], f.leftEyeOpenProbability),
          earRight: _ear(f.contours[FaceContourType.rightEye], f.rightEyeOpenProbability),
          yaw: f.headEulerAngleY,
          pitch: f.headEulerAngleX,
        ));
      }
    } catch (_) {
      // Tek karelik hatalar yok sayılır
    } finally {
      _busy = false;
    }
  }

  /// ML Kit göz konturu 16 noktadır: 0 ve 8 göz köşeleri, diğerleri
  /// alt/üst göz kapakları. 6 noktalı EAR için simetrik noktalar seçilir.
  double? _ear(FaceContour? c, double? openProb) {
    final p = c?.points;
    if (p != null && p.length >= 16) {
      List<double> q(int i) => [p[i].x.toDouble(), p[i].y.toDouble()];
      return eyeAspectRatio([q(0), q(3), q(5), q(8), q(11), q(13)]);
    }
    if (openProb != null) return 0.05 + openProb * 0.25;
    return null;
  }

  /// Kaşların üstünde, alnın ortasında bir dikdörtgen (dik görüntü koordinatı).
  Rect _foreheadRect(Face f) {
    final bb = f.boundingBox;
    double? browTop;
    for (final type in [FaceContourType.leftEyebrowTop, FaceContourType.rightEyebrowTop]) {
      final pts = f.contours[type]?.points;
      if (pts != null && pts.isNotEmpty) {
        final m = pts.map((e) => e.y).reduce(math.min).toDouble();
        browTop = browTop == null ? m : math.min(browTop, m);
      }
    }
    final bottom = (browTop ?? (bb.top + bb.height * 0.25)) - bb.height * 0.03;
    final top = math.max(bb.top + bb.height * 0.02, bottom - bb.height * 0.16);
    final cx = bb.center.dx;
    final halfW = bb.width * 0.2;
    return Rect.fromLTRB(cx - halfW, top, cx + halfW, math.max(bottom, top + 4));
  }

  /// Dik (döndürülmüş) koordinatları ham sensör koordinatlarına çevirir.
  Rect _uprightToRaw(Rect r, int w, int h) {
    Offset map(Offset p) {
      switch (_rotation) {
        case 90:
          return Offset(p.dy, h - 1 - p.dx);
        case 180:
          return Offset(w - 1 - p.dx, h - 1 - p.dy);
        case 270:
          return Offset(w - 1 - p.dy, p.dx);
        default:
          return p;
      }
    }

    final a = map(r.topLeft), b = map(r.bottomRight);
    return Rect.fromPoints(a, b).intersect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
  }

  /// NV21 görüntüde ROI içindeki ortalama Y,U,V → R,G,B.
  List<double>? _roiMeanNv21(Uint8List b, int w, int h, Rect roi) {
    final x0 = roi.left.floor().clamp(0, w - 1);
    final x1 = roi.right.ceil().clamp(0, w);
    final y0 = roi.top.floor().clamp(0, h - 1);
    final y1 = roi.bottom.ceil().clamp(0, h);
    if (x1 - x0 < 4 || y1 - y0 < 4) return null;
    var sy = 0, su = 0, sv = 0, n = 0, nc = 0;
    final uvBase = w * h;
    for (var y = y0; y < y1; y += 2) {
      final row = y * w;
      final uvRow = uvBase + (y >> 1) * w;
      for (var x = x0; x < x1; x += 2) {
        sy += b[row + x];
        n++;
        final uvi = uvRow + (x & ~1);
        if (uvi + 1 < b.length) {
          sv += b[uvi];
          su += b[uvi + 1];
          nc++;
        }
      }
    }
    if (n == 0 || nc == 0) return null;
    final yy = sy / n, u = su / nc - 128, v = sv / nc - 128;
    return [
      yy + 1.402 * v,
      yy - 0.344136 * u - 0.714136 * v,
      yy + 1.772 * u,
    ];
  }
}
