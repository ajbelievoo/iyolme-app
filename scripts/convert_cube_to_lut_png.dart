import 'dart:io';

import 'package:image/image.dart' as img;

class CubeLut {
  CubeLut({
    required this.size,
    required this.data,
    required this.domainMin,
    required this.domainMax,
  });

  final int size;
  final List<double> data; // r,g,b triples length = size^3*3
  final List<double> domainMin;
  final List<double> domainMax;

  int _idx(int r, int g, int b) {
    // Common .cube ordering: B fastest, then G, then R.
    // index = ((r * size + g) * size + b) * 3
    return ((r * size + g) * size + b) * 3;
  }

  List<double> sample(double r, double g, double b) {
    // Apply domain
    final rr = _clamp01((r - domainMin[0]) / (domainMax[0] - domainMin[0]));
    final gg = _clamp01((g - domainMin[1]) / (domainMax[1] - domainMin[1]));
    final bb = _clamp01((b - domainMin[2]) / (domainMax[2] - domainMin[2]));

    final fx = rr * (size - 1);
    final fy = gg * (size - 1);
    final fz = bb * (size - 1);

    final x0 = fx.floor().clamp(0, size - 1);
    final y0 = fy.floor().clamp(0, size - 1);
    final z0 = fz.floor().clamp(0, size - 1);
    final x1 = (x0 + 1).clamp(0, size - 1);
    final y1 = (y0 + 1).clamp(0, size - 1);
    final z1 = (z0 + 1).clamp(0, size - 1);

    final tx = (fx - x0).clamp(0.0, 1.0);
    final ty = (fy - y0).clamp(0.0, 1.0);
    final tz = (fz - z0).clamp(0.0, 1.0);

    List<double> at(int xi, int yi, int zi) {
      final i = _idx(xi, yi, zi);
      return [data[i], data[i + 1], data[i + 2]];
    }

    // Trilinear interpolation
    final c000 = at(x0, y0, z0);
    final c100 = at(x1, y0, z0);
    final c010 = at(x0, y1, z0);
    final c110 = at(x1, y1, z0);
    final c001 = at(x0, y0, z1);
    final c101 = at(x1, y0, z1);
    final c011 = at(x0, y1, z1);
    final c111 = at(x1, y1, z1);

    List<double> lerp3(List<double> a, List<double> b, double t) {
      return [
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
      ];
    }

    final c00 = lerp3(c000, c100, tx);
    final c10 = lerp3(c010, c110, tx);
    final c01 = lerp3(c001, c101, tx);
    final c11 = lerp3(c011, c111, tx);
    final c0 = lerp3(c00, c10, ty);
    final c1 = lerp3(c01, c11, ty);
    final c = lerp3(c0, c1, tz);

    return [
      _clamp01(c[0]),
      _clamp01(c[1]),
      _clamp01(c[2]),
    ];
  }
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run scripts/convert_cube_to_lut_png.dart <path-to-cube-or-folder>');
    exitCode = 2;
    return;
  }

  final input = args.first;
  final entity = FileSystemEntity.typeSync(input);
  final files = <File>[];

  if (entity == FileSystemEntityType.file) {
    if (!input.toLowerCase().endsWith('.cube')) {
      stderr.writeln('Input file must be .cube');
      exitCode = 2;
      return;
    }
    files.add(File(input));
  } else if (entity == FileSystemEntityType.directory) {
    final dir = Directory(input);
    files.addAll(dir
        .listSync(recursive: false)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.cube')));
    if (files.isEmpty) {
      stderr.writeln('No .cube files found in: $input');
      exitCode = 2;
      return;
    }
  } else {
    stderr.writeln('Path not found: $input');
    exitCode = 2;
    return;
  }

  final outDir = Directory('assets/luts');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  for (final f in files) {
    final cube = _parseCube(f);
    if (cube == null) {
      stderr.writeln('Failed to parse: ${f.path}');
      continue;
    }

    final png = _buildLut512FromCube(cube);
    final base = _baseNameNoExt(f.path);
    final outPath = 'assets/luts/$base.png';
    File(outPath).writeAsBytesSync(img.encodePng(png, level: 6), flush: true);
    stdout.writeln('Wrote $outPath (from ${f.path}, size=${cube.size})');
  }
}

CubeLut? _parseCube(File file) {
  try {
    final lines = file.readAsLinesSync();

    int? size;
    var domainMin = <double>[0, 0, 0];
    var domainMax = <double>[1, 1, 1];
    final values = <double>[];

    for (var raw in lines) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) continue;

      // Remove inline comments
      final hash = line.indexOf('#');
      if (hash >= 0) line = line.substring(0, hash).trim();
      if (line.isEmpty) continue;

      final upper = line.toUpperCase();
      if (upper.startsWith('TITLE')) {
        continue;
      }
      if (upper.startsWith('LUT_3D_SIZE')) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          size = int.tryParse(parts[1]);
        }
        continue;
      }
      if (upper.startsWith('DOMAIN_MIN')) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          domainMin = [
            double.parse(parts[1]),
            double.parse(parts[2]),
            double.parse(parts[3]),
          ];
        }
        continue;
      }
      if (upper.startsWith('DOMAIN_MAX')) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          domainMax = [
            double.parse(parts[1]),
            double.parse(parts[2]),
            double.parse(parts[3]),
          ];
        }
        continue;
      }

      // Data line: r g b
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        final r = double.parse(parts[0]);
        final g = double.parse(parts[1]);
        final b = double.parse(parts[2]);
        values.add(r);
        values.add(g);
        values.add(b);
      }
    }

    if (size == null || size <= 1) return null;
    final expected = size * size * size * 3;
    if (values.length != expected) {
      // Some files may have extra spaces/lines; if too many, truncate.
      if (values.length < expected) return null;
      values.removeRange(expected, values.length);
    }

    return CubeLut(
      size: size,
      data: values,
      domainMin: domainMin,
      domainMax: domainMax,
    );
  } catch (_) {
    return null;
  }
}

img.Image _buildLut512FromCube(CubeLut cube) {
  const int outSize = 512;
  const int tiles = 8;
  const int tileSize = 64;
  final out = img.Image(width: outSize, height: outSize);

  for (int y = 0; y < outSize; y++) {
    final tileY = y ~/ tileSize;
    final gy = y % tileSize;
    final g = gy / 63.0;

    for (int x = 0; x < outSize; x++) {
      final tileX = x ~/ tileSize;
      final rx = x % tileSize;
      final r = rx / 63.0;

      final bIndex = tileY * tiles + tileX; // 0..63
      final b = bIndex / 63.0;

      final c = cube.sample(r, g, b);
      out.setPixelRgb(x, y, _to8(c[0]), _to8(c[1]), _to8(c[2]));
    }
  }

  return out;
}

String _baseNameNoExt(String path) {
  final p = path.replaceAll('\\', '/');
  final last = p.substring(p.lastIndexOf('/') + 1);
  final dot = last.lastIndexOf('.');
  return dot > 0 ? last.substring(0, dot) : last;
}

int _to8(double v) {
  final x = (v.clamp(0.0, 1.0) * 255.0).round();
  return x.clamp(0, 255);
}

double _clamp01(double v) {
  if (v.isNaN) return 0.0;
  if (v.isInfinite) return v.isNegative ? 0.0 : 1.0;
  return v < 0 ? 0 : (v > 1 ? 1 : v);
}
