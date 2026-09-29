import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main(List<String> args) {
  final outDir = Directory('assets/luts');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final presets = <String, img.ColorRgb8 Function(double r, double g, double b)>{
    'identity': _identity,
    'warm': _warm,
    'cool': _cool,
    'vivid': _vivid,
    'sweet': _sweet,
    'cinema': _cinema,
    'glow': _glow,
  };

  for (final e in presets.entries) {
    final name = e.key;
    final fn = e.value;
    final image = _buildLut512(fn);
    final bytes = img.encodePng(image, level: 6);
    final file = File('assets/luts/$name.png');
    file.writeAsBytesSync(bytes, flush: true);
    stdout.writeln('Wrote ${file.path} (${bytes.length} bytes)');
  }
}

img.Image _buildLut512(img.ColorRgb8 Function(double r, double g, double b) mapFn) {
  // 64 slices (blue), arranged 8x8 tiles.
  // Each tile is 64x64. X inside tile is red (0..63), Y inside tile is green (0..63).
  const int size = 512;
  const int tiles = 8;
  const int tileSize = 64;
  final out = img.Image(width: size, height: size);

  for (int y = 0; y < size; y++) {
    final tileY = y ~/ tileSize;
    final gy = y % tileSize;
    final g = gy / 63.0;

    for (int x = 0; x < size; x++) {
      final tileX = x ~/ tileSize;
      final rx = x % tileSize;
      final r = rx / 63.0;

      final bIndex = tileY * tiles + tileX; // 0..63
      final b = bIndex / 63.0;

      final c = mapFn(r, g, b);
      out.setPixelRgb(x, y, c.r, c.g, c.b);
    }
  }

  return out;
}

img.ColorRgb8 _identity(double r, double g, double b) {
  return img.ColorRgb8(_to8(r), _to8(g), _to8(b));
}

img.ColorRgb8 _warm(double r, double g, double b) {
  var c = _applySaturation(r, g, b, 1.08);
  c = _applyContrast(c[0], c[1], c[2], 1.06);
  c[0] = _clamp01(c[0] + 0.045);
  c[2] = _clamp01(c[2] - 0.035);
  c[1] = _clamp01(c[1] + 0.010);
  c = _applyGamma(c[0], c[1], c[2], 0.98);
  return img.ColorRgb8(_to8(c[0]), _to8(c[1]), _to8(c[2]));
}

img.ColorRgb8 _cool(double r, double g, double b) {
  var c = _applySaturation(r, g, b, 1.05);
  c = _applyContrast(c[0], c[1], c[2], 1.04);
  c[2] = _clamp01(c[2] + 0.055);
  c[0] = _clamp01(c[0] - 0.030);
  c[1] = _clamp01(c[1] + 0.010);
  c = _applyGamma(c[0], c[1], c[2], 1.01);
  return img.ColorRgb8(_to8(c[0]), _to8(c[1]), _to8(c[2]));
}

img.ColorRgb8 _vivid(double r, double g, double b) {
  var c = _applySaturation(r, g, b, 1.25);
  c = _applyContrast(c[0], c[1], c[2], 1.12);
  c = _applyVibrance(c[0], c[1], c[2], 0.28);
  c = _applyGamma(c[0], c[1], c[2], 0.98);
  return img.ColorRgb8(_to8(c[0]), _to8(c[1]), _to8(c[2]));
}

img.ColorRgb8 _sweet(double r, double g, double b) {
  // Soft highlights + lifted shadows + a hint of pink.
  var c = _applyLiftGammaGain(r, g, b, 0.03, 0.98, 1.04);
  c = _applySaturation(c[0], c[1], c[2], 1.10);
  c[0] = _clamp01(c[0] + 0.020);
  c[2] = _clamp01(c[2] - 0.010);
  c = _applyContrast(c[0], c[1], c[2], 1.02);
  c = _applySoftClip(c[0], c[1], c[2], 0.92);
  return img.ColorRgb8(_to8(c[0]), _to8(c[1]), _to8(c[2]));
}

img.ColorRgb8 _cinema(double r, double g, double b) {
  // Teal shadows + warm highlights + slight fade.
  var c = _applyContrast(r, g, b, 1.08);
  c = _applyFade(c[0], c[1], c[2], 0.06);

  final lum = _luma(c[0], c[1], c[2]);
  final t = _smoothstep(0.20, 0.85, lum);

  // Shadows teal
  c[1] = _clamp01(c[1] + (1.0 - t) * 0.030);
  c[2] = _clamp01(c[2] + (1.0 - t) * 0.060);

  // Highlights warm
  c[0] = _clamp01(c[0] + t * 0.050);
  c[2] = _clamp01(c[2] - t * 0.015);

  c = _applySaturation(c[0], c[1], c[2], 1.06);
  c = _applyGamma(c[0], c[1], c[2], 1.00);
  return img.ColorRgb8(_to8(c[0]), _to8(c[1]), _to8(c[2]));
}

img.ColorRgb8 _glow(double r, double g, double b) {
  // "Glow" in LUT sense: lifted highlights + smoother midtones.
  // Real glow comes from shader; this gives a pleasant filmic rolloff.
  var c = _applyLiftGammaGain(r, g, b, 0.02, 0.97, 1.02);
  c = _applySoftClip(c[0], c[1], c[2], 0.90);
  c = _applySaturation(c[0], c[1], c[2], 1.05);
  c = _applyGamma(c[0], c[1], c[2], 0.99);
  return img.ColorRgb8(_to8(c[0]), _to8(c[1]), _to8(c[2]));
}

int _to8(double v) {
  final x = (v * 255.0).round();
  if (x < 0) return 0;
  if (x > 255) return 255;
  return x;
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double _luma(double r, double g, double b) => 0.299 * r + 0.587 * g + 0.114 * b;

double _smoothstep(double a, double b, double x) {
  final t = _clamp01((x - a) / (b - a));
  return t * t * (3.0 - 2.0 * t);
}

List<double> _applyContrast(double r, double g, double b, double contrast) {
  // contrast around 0.5
  final c = contrast;
  r = _clamp01((r - 0.5) * c + 0.5);
  g = _clamp01((g - 0.5) * c + 0.5);
  b = _clamp01((b - 0.5) * c + 0.5);
  return [r, g, b];
}

List<double> _applyGamma(double r, double g, double b, double gamma) {
  final inv = 1.0 / math.max(0.0001, gamma);
  r = _clamp01(math.pow(r, inv).toDouble());
  g = _clamp01(math.pow(g, inv).toDouble());
  b = _clamp01(math.pow(b, inv).toDouble());
  return [r, g, b];
}

List<double> _applySaturation(double r, double g, double b, double sat) {
  final l = _luma(r, g, b);
  r = _clamp01(l + (r - l) * sat);
  g = _clamp01(l + (g - l) * sat);
  b = _clamp01(l + (b - l) * sat);
  return [r, g, b];
}

List<double> _applyVibrance(double r, double g, double b, double amount) {
  // Boost saturation more for low-sat colors.
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final sat = (maxC - minC);
  final vib = 1.0 + amount * (1.0 - sat);
  return _applySaturation(r, g, b, vib);
}

List<double> _applyLiftGammaGain(double r, double g, double b, double lift, double gamma, double gain) {
  r = _clamp01((r + lift) * gain);
  g = _clamp01((g + lift) * gain);
  b = _clamp01((b + lift) * gain);
  return _applyGamma(r, g, b, gamma);
}

List<double> _applyFade(double r, double g, double b, double amount) {
  // Lift blacks slightly.
  r = _clamp01(r * (1.0 - amount) + amount * 0.10);
  g = _clamp01(g * (1.0 - amount) + amount * 0.10);
  b = _clamp01(b * (1.0 - amount) + amount * 0.10);
  return [r, g, b];
}

List<double> _applySoftClip(double r, double g, double b, double threshold) {
  r = _softClip1(r, threshold);
  g = _softClip1(g, threshold);
  b = _softClip1(b, threshold);
  return [r, g, b];
}

double _softClip1(double x, double t) {
  if (x <= t) return x;
  final over = x - t;
  return _clamp01(t + over / (1.0 + over * 6.0));
}
