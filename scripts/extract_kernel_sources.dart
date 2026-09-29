// Extract embedded Dart sources from a Flutter debug kernel_blob.bin.
// Real entries look like '<bin>file:///<path>.dart<varint-gap>source'.
// Pass 1 (strict): gap between URI and source must be all non-printable bytes.
// Pass 2 (relaxed): gap may contain printable bytes (varint artifacts) — only
// fills paths not recovered in pass 1.
import 'dart:convert';
import 'dart:io';

const markers = ['file:///E:/flutterapp_pro/', 'package:shortzz/'];

final startTokens = [
  '//', '/*', "import '", 'import "', 'library ', 'part ', 'class ',
  'enum ', 'mixin ', 'extension ', 'typedef ', 'void ', 'final ', 'const ',
  'abstract ',
];

bool printableAscii(int b) => b >= 32 && b <= 126;
bool wsOrPrint(int b) => b == 9 || b == 10 || b == 13 || printableAscii(b);

int utf8TextLen(List<int> b, int start, int end) {
  var i = start;
  while (i < end) {
    final c = b[i];
    if (wsOrPrint(c)) {
      i++;
    } else if (c >= 0xC2 && c <= 0xDF && i + 1 < end && _cont(b[i + 1])) {
      i += 2;
    } else if (c >= 0xE0 && c <= 0xEF &&
        i + 2 < end && _cont(b[i + 1]) && _cont(b[i + 2])) {
      i += 3;
    } else if (c >= 0xF0 && c <= 0xF4 &&
        i + 3 < end && _cont(b[i + 1]) && _cont(b[i + 2]) && _cont(b[i + 3])) {
      i += 4;
    } else {
      break;
    }
  }
  return i - start;
}

bool _cont(int c) => c >= 0x80 && c <= 0xBF;

final recovered = <String, int>{};
final strictKeys = <String>{};

void tryExtract(List<int> bytes, int uriStart, int uriEnd, String marker,
    String rel, {required bool strict}) {
  var srcStart = -1;
  for (var k = 0; k <= 8; k++) {
    final pos = uriEnd + k;
    if (pos >= bytes.length) break;
    final c = bytes[pos];
    final winEnd = (pos + 40).clamp(0, bytes.length);
    final w = String.fromCharCodes(bytes.sublist(pos, winEnd));
    if (startTokens.any(w.startsWith)) {
      srcStart = pos;
      break;
    }
    // printable ASCII ends the gap in strict mode; binary bytes continue it
    if (wsOrPrint(c) && strict) break;
    if (wsOrPrint(c) && !strict) continue;
    // non-printable gap byte — keep scanning
  }
  if (srcStart < 0) return;

  var len = utf8TextLen(bytes, srcStart, bytes.length);
  if (len < 40) return;
  // Cut at next embedded URI entry (overrun into the following source).
  final span = bytes.sublist(srcStart, srcStart + len);
  for (final pat in ['file:///E:/', 'file:///C:/']) {
    final cut = _indexOf(span, utf8.encode(pat), 100);
    if (cut > 0) len = cut < len ? cut : len;
  }
  // Bare 'package:shortzz/x.dart' URI entry (an import line would be quoted)
  final pkgPat = utf8.encode('package:shortzz/');
  var p = 100;
  while (true) {
    final idx = _indexOf(span, pkgPat, p);
    if (idx < 0) break;
    final prev = span[idx - 1];
    if (prev != 39 && prev != 34) {
      // not quoted — check it looks like a bare URI: path chars then '.dart'
      var q = idx + pkgPat.length;
      var pl = 0;
      while (q + pl < span.length && pl < 120) {
        final c = span[q + pl];
        final ok = (c >= 97 && c <= 122) || (c >= 65 && c <= 90) ||
            (c >= 48 && c <= 57) || c == 95 || c == 47 || c == 46;
        if (!ok) break;
        pl++;
      }
      if (pl > 5 &&
          span[q + pl - 5] == 46 && span[q + pl - 4] == 100 &&
          span[q + pl - 3] == 97 && span[q + pl - 2] == 114 &&
          span[q + pl - 1] == 116) {
        len = idx;
        break;
      }
    }
    p = idx + 1;
  }

  final outRel = marker.startsWith('package:') ? 'lib/$rel' : rel;
  if (!strict && strictKeys.contains(outRel)) return;
  if (!recovered.containsKey(outRel) || recovered[outRel]! < len) {
    final f = File('scripts/kernel_recovered/$outRel');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes.sublist(srcStart, srcStart + len));
    recovered[outRel] = len;
  }
}

void scan(List<int> bytes, {required bool strict}) {
  for (final marker in markers) {
    final mb = utf8.encode(marker);
    var i = 0;
    while (i < bytes.length - mb.length - 8) {
      var match = true;
      for (var k = 0; k < mb.length; k++) {
        if (bytes[i + k] != mb[k]) {
          match = false;
          break;
        }
      }
      if (!match) {
        i++;
        continue;
      }
      // String-table rejection: real [bin][uri][src] entries have binary
      // bytes just before the URI; in the string table the previous string's
      // tail (printable text) touches the marker. Require a control byte
      // within the 6 bytes before the marker.
      var hasCtl = false;
      for (var k = 1; k <= 6 && i - k >= 0; k++) {
        if (bytes[i - k] < 0x20) {
          hasCtl = true;
          break;
        }
      }
      if (!hasCtl) {
        i += mb.length;
        continue;
      }
      // URI ends at first '.dart'
      var uriEnd = -1;
      var j = i + mb.length;
      while (j < bytes.length - 5 && printableAscii(bytes[j])) {
        if (bytes[j] == 46 &&
            bytes[j + 1] == 100 &&
            bytes[j + 2] == 97 &&
            bytes[j + 3] == 114 &&
            bytes[j + 4] == 116) {
          uriEnd = j + 5;
          break;
        }
        j++;
      }
      if (uriEnd < 0) {
        i++;
        continue;
      }
      final rel =
          utf8.decode(bytes.sublist(i + mb.length, uriEnd), allowMalformed: true);
      tryExtract(bytes, i, uriEnd, marker, rel, strict: strict);
      i = uriEnd;
    }
  }
}

void main(List<String> args) {
  final bytes = File(args[0]).readAsBytesSync();
  print('blob size: ${bytes.length}');
  scan(bytes, strict: true);
  print('after strict pass: ${recovered.length}');
  strictKeys.addAll(recovered.keys);
  scan(bytes, strict: false);
  // Relaxed pass must not overwrite good strict results with shorter junk
  print('total recovered: ${recovered.length}');
  recovered.forEach((k, v) =>
      print('  ${strictKeys.contains(k) ? 'S' : 'R'} $k ($v)'));
}

int _indexOf(List<int> hay, List<int> needle, int start) {
  outer:
  for (var i = start; i <= hay.length - needle.length; i++) {
    for (var k = 0; k < needle.length; k++) {
      if (hay[i + k] != needle[k]) continue outer;
    }
    return i;
  }
  return -1;
}
