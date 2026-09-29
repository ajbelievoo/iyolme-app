import 'dart:convert';
import 'dart:io';

void main() {
  final b = File('build/app/intermediates/flutter/debug/flutter_assets/kernel_blob.bin').readAsBytesSync();
  // known isolated URI offsets
  final tests = {
    'story_ad_view': 95010109,
    'scratch_collect_models': 95282633,
    'home_screen_controller': 96915562,
  };
  for (final e in tests.entries) {
    // find '.dart' end
    var p = e.value;
    while (!(b[p] == 46 && b[p + 1] == 100 && b[p + 2] == 97 && b[p + 3] == 114 && b[p + 4] == 116)) {
      p++;
    }
    final uriEnd = p + 5;
    print('=== ${e.key} uriEnd=$uriEnd bytes: ${b.sublist(uriEnd, uriEnd + 6).map((x) => x.toRadixString(16)).join(' ')}');
    // try LEB128 varint at offsets 0..3
    for (var off = 0; off < 4; off++) {
      var pos = uriEnd + off;
      var val = 0, shift = 0, consumed = 0;
      while (pos + consumed < b.length && consumed < 10) {
        final byte = b[pos + consumed];
        val |= (byte & 0x7f) << shift;
        consumed++;
        if (byte & 0x80 == 0) break;
        shift += 7;
      }
      final start = pos + consumed;
      if (val > 0 && val < 500000 && start + val <= b.length) {
        final chunk = b.sublist(start, start + val);
        try {
          final s = utf8.decode(chunk);
          final trimmed = s.trimRight();
          final lastChar = trimmed.isEmpty ? '?' : trimmed[trimmed.length - 1];
          final startsOk = s.startsWith('import') || s.startsWith('//') || s.startsWith('class') || s.startsWith('enum');
          print('  off=$off len=$val start-ok=$startsOk last="$lastChar"');
        } catch (_) {
          print('  off=$off len=$val UTF8-FAIL');
        }
      } else {
        print('  off=$off len=$val (invalid)');
      }
    }
  }
}
