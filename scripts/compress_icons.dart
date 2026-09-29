import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  compress('assets/icons/app_icon.png', 'assets/icons/app_icon_opt.png', 1024);
  compress('assets/icons/app_splash.png', 'assets/icons/app_splash_opt.png', 1152);
}

void compress(String src, String dst, int maxW) {
  final srcFile = File(src);
  final dstFile = File(dst);
  final before = srcFile.lengthSync();
  var im = img.decodeImage(srcFile.readAsBytesSync());
  if (im == null) {
    print('FAIL decode $src');
    return;
  }
  if (im.width > maxW) {
    im = img.copyResize(im, width: maxW);
  }
  dstFile.writeAsBytesSync(img.encodePng(im!, level: 9));
  print('$dst: ${before ~/ 1024}KB -> ${dstFile.lengthSync() ~/ 1024}KB (${im.width}x${im.height})');
}
