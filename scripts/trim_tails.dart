import 'dart:io';

void main() {
  var fixed = 0, scanned = 0;
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    scanned++;
    var txt = f.readAsStringSync();
    if (txt.isEmpty) continue;
    final lastBrace = txt.lastIndexOf('}');
    final lastSemi = txt.lastIndexOf(';');
    var cut = lastBrace > lastSemi ? lastBrace : lastSemi;
    if (cut < 0) continue;
    final tail = txt.substring(cut + 1);
    final t = tail.trim();
    // Junk tails are short fragments: no code keywords, no '=', no comments
    if (t.isNotEmpty &&
        t.length < 60 &&
        !t.contains('=') &&
        !t.startsWith('//') &&
        !t.startsWith('/*') &&
        !t.startsWith('part')) {
      f.writeAsStringSync(txt.substring(0, cut + 1) + '\n');
      fixed++;
    }
  }
  print('scanned: $scanned fixed: $fixed');
}
