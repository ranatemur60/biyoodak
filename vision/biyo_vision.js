// BiyoOdak web sürümü: MediaPipe Face Landmarker ile yüz analizi.
// Tüm işlem tarayıcıda (cihaz üzerinde) yapılır; görüntü hiçbir yere gönderilmez.
import { FaceLandmarker, FilesetResolver } from './vision_bundle.mjs';

const EYE_A = [33, 160, 158, 133, 153, 144];
const EYE_B = [362, 385, 387, 263, 373, 380];

let landmarker = null;
let stream = null;
let running = false;
let video = null;
let cb = null;
let canvas = null;
let ctx = null;
let t0 = 0;
let lastDetect = -1e9;
let roi = null; // {x,y,w,h} canvas pikseli

async function init() {
  if (landmarker) return;
  const base = new URL('.', import.meta.url).href;
  const fileset = await FilesetResolver.forVisionTasks(base + 'wasm');
  const opts = (delegate) => ({
    baseOptions: { modelAssetPath: base + 'face_landmarker.task', delegate },
    runningMode: 'VIDEO',
    numFaces: 1,
  });
  try {
    landmarker = await FaceLandmarker.createFromOptions(fileset, opts('GPU'));
  } catch (e) {
    landmarker = await FaceLandmarker.createFromOptions(fileset, opts('CPU'));
  }
}

function dist(a, b, W, H) {
  const dx = (a.x - b.x) * W, dy = (a.y - b.y) * H;
  return Math.sqrt(dx * dx + dy * dy);
}

function ear(lm, idx, W, H) {
  const p = idx.map((i) => lm[i]);
  const h = dist(p[0], p[3], W, H);
  if (h === 0) return null;
  return (dist(p[1], p[5], W, H) + dist(p[2], p[4], W, H)) / (2 * h);
}

function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

function loop() {
  if (!running) return;
  const now = performance.now();
  const t = now - t0;
  if (video.readyState >= 2) {
    const W = video.videoWidth, H = video.videoHeight;
    if (!canvas) {
      canvas = document.createElement('canvas');
      ctx = canvas.getContext('2d', { willReadFrequently: true });
    }
    const cw = 320, ch = Math.round(320 * H / W) || 240;
    if (canvas.width !== cw) { canvas.width = cw; canvas.height = ch; }
    if (now - lastDetect > 60) {
      lastDetect = now;
      try {
        const res = landmarker.detectForVideo(video, now);
        const lm = res.faceLandmarks && res.faceLandmarks[0];
        if (!lm) {
          roi = null;
          cb({ k: 1, t, face: false });
        } else {
          const l = lm[234], r = lm[454], nose = lm[1], top = lm[10], chin = lm[152];
          const ratioX = (nose.x - l.x) / ((r.x - l.x) || 1e-6);
          const yaw = Math.asin(clamp(2 * ratioX - 1, -1, 1)) * 180 / Math.PI;
          const ratioY = (nose.y - top.y) / ((chin.y - top.y) || 1e-6);
          const pitch = Math.asin(clamp((ratioY - 0.52) * 2.2, -1, 1)) * 180 / Math.PI;
          const fc = lm[151];
          const fw = Math.abs(r.x - l.x) * 0.35 * cw;
          const fh = Math.abs(chin.y - top.y) * 0.10 * ch;
          roi = { x: Math.round(fc.x * cw - fw / 2), y: Math.round(fc.y * ch - fh / 2),
                  w: Math.max(4, Math.round(fw)), h: Math.max(4, Math.round(fh)) };
          cb({ k: 1, t, face: true, el: ear(lm, EYE_A, W, H), er: ear(lm, EYE_B, W, H), yaw, pitch });
        }
      } catch (e) { /* tek kare hatası */ }
    }
    if (roi) {
      ctx.drawImage(video, 0, 0, cw, ch);
      const x = clamp(roi.x, 0, cw - 4), y = clamp(roi.y, 0, ch - 4);
      const w = Math.min(roi.w, cw - x), h = Math.min(roi.h, ch - y);
      const d = ctx.getImageData(x, y, w, h).data;
      let sr = 0, sg = 0, sb = 0, n = 0;
      for (let i = 0; i < d.length; i += 4) { sr += d[i]; sg += d[i + 1]; sb += d[i + 2]; n++; }
      if (n > 0) cb({ k: 0, t, r: sr / n, g: sg / n, b: sb / n });
    }
  }
  if (video.requestVideoFrameCallback) video.requestVideoFrameCallback(loop);
  else requestAnimationFrame(loop);
}

async function start(videoEl, callback) {
  video = videoEl;
  cb = callback;
  if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    throw new Error('Bu tarayıcı kamera erişimini desteklemiyor (HTTPS gerekir).');
  }
  stream = await navigator.mediaDevices.getUserMedia({
    video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { ideal: 30 } },
    audio: false,
  });
  video.muted = true;
  video.setAttribute('playsinline', '');
  video.setAttribute('autoplay', '');
  video.srcObject = stream;
  await video.play();
  await init();
  running = true;
  t0 = performance.now();
  roi = null;
  loop();
}

function stop() {
  running = false;
  if (stream) stream.getTracks().forEach((t) => t.stop());
  stream = null;
  if (video) video.srcObject = null;
}

function preload() { init().catch(() => {}); }

window.biyoVision = { start, stop, preload };
