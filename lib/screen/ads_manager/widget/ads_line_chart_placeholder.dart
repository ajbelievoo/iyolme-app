import 'package:flutter/material.dart';
import 'package:shortzz/utilities/theme_res.dart';

class AdsLineChartPlaceholder extends StatelessWidget {
  const AdsLineChartPlaceholder({
    super.key,
    this.height = 160,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textLightGrey(context).withValues(alpha: 0.16),
        ),
      ),
      child: CustomPaint(
        painter: _LinePainter(
          lineColor: themeAccentSolid(context),
          gridColor: Colors.black.withValues(alpha: 0.06),
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            'Chart (API ready later)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textLightGrey(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.lineColor,
    required this.gridColor,
  });

  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final fillPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final points = <Offset>[
      Offset(0, size.height * 0.65),
      Offset(size.width * 0.18, size.height * 0.50),
      Offset(size.width * 0.35, size.height * 0.58),
      Offset(size.width * 0.52, size.height * 0.40),
      Offset(size.width * 0.70, size.height * 0.48),
      Offset(size.width * 0.88, size.height * 0.30),
      Offset(size.width, size.height * 0.36),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor || oldDelegate.gridColor != gridColor;
  }
}
