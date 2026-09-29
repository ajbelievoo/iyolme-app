import 'dart:ui';

import 'package:meta/meta.dart';

import 'package:pretty_qr_code/src/painting/pretty_qr_clipper.dart';

/// {@template pretty_qr_code.painting.PrettyQrCircleClipper}
/// A circular clipper for QR code embedded images.
/// {@endtemplate}
class PrettyQrCircleClipper implements PrettyQrClipper {
  /// {@macro pretty_qr_code.painting.PrettyQrCircleClipper}
  @literal
  const PrettyQrCircleClipper();

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
  }
}
