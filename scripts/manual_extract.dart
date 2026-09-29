import 'dart:io';
import 'dart:convert';

void main() {
  final b = File('build/app/intermediates/flutter/debug/flutter_assets/kernel_blob.bin').readAsBytesSync();
  final jobs = <String, int>{
    'lib/common/widget/story_ad_view.dart': 95010109,
    'lib/model/scratch_collect/scratch_collect_models.dart': 95282633,
  };
  final uriMarker = utf8.encode('file:///');
  for (final e in jobs.entries) {
    // find URI end: '.dart' after e.value
    var p = e.value + uriMarker.length;
    while (!(b[p] == 46 && b[p + 1] == 100 && b[p + 2] == 97 && b[p + 3] == 114 && b[p + 4] == 116)) {
      p++;
    }
    var start = p + 5;
    // skip non-printable gap bytes (allow \n \t as source start edge)
    while (start < b.length && (b[start] < 32 || b[start] > 126)) {
      start++;
    }
    final chunk = b.sublist(start, start + 200000);
    final s = latin1.decode(chunk);
    var end = s.indexOf('file:///');
    final re = RegExp(r"package:shortzz/[A-Za-z0-9_/]+\.dart[^';]");
    final m = re.firstMatch(s);
    if (m != null && (end < 0 || m.start < end)) end = m.start;
    if (end < 0) end = 150000;
    var text = utf8.decode(chunk.sublist(0, end), allowMalformed: true);
    // trim leading garbage: drop everything before first real token
    final tok = RegExp(r"(import |//|class |enum |mixin |extension |typedef |final |const |library |part |void |abstract )");
    final tm = tok.firstMatch(text);
    if (tm != null) text = text.substring(tm.start);
    // trim trailing binary lineStarts table: keep up to last '}' or ';\n'
    var cut = text.lastIndexOf('}');
    if (cut > 0) text = text.substring(0, cut + 1);
    print('===== ${e.key} (${text.length} chars) =====');
    print(text.substring(text.length > 200 ? text.length - 200 : 0));
    final f = File('scripts/kernel_recovered/${e.key}');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(text + '\n');
  }
}
