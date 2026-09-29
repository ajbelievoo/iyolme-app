import 'dart:io';

String pascal(String s) => s
    .split('_')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
    .join();

void main() {
  var bad = 0, checked = 0;
  final files = Directory('scripts/kernel_recovered')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final f in files) {
    final name = f.uri.pathSegments.last.replaceAll('.dart', '');
    final txt = f.readAsStringSync();
    checked++;
    final expected = pascal(name);
    if (!txt.contains(expected) && !txt.contains(name)) {
      print('MISMATCH ${f.path} (expected ~$expected)');
      bad++;
    }
  }
  print('checked: $checked mismatches: $bad');
}
