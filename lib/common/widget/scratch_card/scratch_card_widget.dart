import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ScratchCard extends StatefulWidget {
  final Widget child;
  final double width;
  final double height;
  final Color overlayColor;
  final Widget? overlayWidget;
  final VoidCallback? onScratchComplete;
  final double scratchThreshold;
  final Function(double)? onScratchProgress;

  const ScratchCard({
    super.key,
    required this.child,
    required this.width,
    required this.height,
    this.overlayColor = const Color(0xFFC0C0C0),
    this.overlayWidget,
    this.onScratchComplete,
    this.scratchThreshold = 0.4,
    this.onScratchProgress,
  });

  @override
  State<ScratchCard> createState() => _ScratchCardState();
}

class _ScratchCardState extends State<ScratchCard> {
  final List<Offset> _scratchPoints = [];
  ui.Image? _scratchPattern;
  bool _isScratched = false;
  double _scratchProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadScratchPattern();
  }

  Future<void> _loadScratchPattern() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = widget.overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, widget.width, widget.height),
      paint,
    );

    // Add silver gradient effect
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFE8E8E8),
        Color(0xFFC0C0C0),
        Color(0xFF909090),
        Color(0xFFC0C0C0),
        Color(0xFFE8E8E8),
      ],
      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    final gradientPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, widget.width, widget.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, widget.width, widget.height),
      gradientPaint,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      widget.width.toInt(),
      widget.height.toInt(),
    );

    setState(() {
      _scratchPattern = image;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isScratched) return;

    final localPosition = details.localPosition;
    if (_isPointInside(localPosition)) {
      setState(() {
        _scratchPoints.add(localPosition);
      });
      _calculateScratchProgress();
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_scratchProgress >= widget.scratchThreshold && !_isScratched) {
      setState(() {
        _isScratched = true;
      });
      widget.onScratchComplete?.call();
    }
  }

  bool _isPointInside(Offset point) {
    return point.dx >= 0 &&
        point.dx <= widget.width &&
        point.dy >= 0 &&
        point.dy <= widget.height;
  }

  void _calculateScratchProgress() {
    if (_scratchPoints.isEmpty) return;

    final totalArea = widget.width * widget.height;
    final scratchedArea = _scratchPoints.length * 500; // Approximation
    final progress = min(scratchedArea / totalArea, 1.0);

    setState(() {
      _scratchProgress = progress;
    });

    widget.onScratchProgress?.call(progress);
  }

  void reset() {
    setState(() {
      _scratchPoints.clear();
      _isScratched = false;
      _scratchProgress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          children: [
            // Reward content
            widget.child,

            // Scratch overlay
            if (!_isScratched && _scratchPattern != null)
              GestureDetector(
                onPanUpdate: _handlePanUpdate,
                onPanEnd: _handlePanEnd,
                child: CustomPaint(
                  size: Size(widget.width, widget.height),
                  painter: ScratchPainter(
                    pattern: _scratchPattern!,
                    scratchPoints: _scratchPoints,
                    brushSize: 40,
                  ),
                  child: widget.overlayWidget,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ScratchPainter extends CustomPainter {
  final ui.Image pattern;
  final List<Offset> scratchPoints;
  final double brushSize;

  ScratchPainter({
    required this.pattern,
    required this.scratchPoints,
    required this.brushSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Create a path from scratch points
    final path = Path();
    if (scratchPoints.isNotEmpty) {
      path.moveTo(scratchPoints.first.dx, scratchPoints.first.dy);
      for (var i = 1; i < scratchPoints.length; i++) {
        path.lineTo(scratchPoints[i].dx, scratchPoints[i].dy);
      }
    }

    // Create scratch layer
    final recorder = ui.PictureRecorder();
    final scratchCanvas = Canvas(recorder);

    // Draw the pattern
    scratchCanvas.drawImage(pattern, Offset.zero, Paint());

    // Clear scratched areas using destinationOut blend mode
    for (final point in scratchPoints) {
      final paint = Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.fill;

      scratchCanvas.drawCircle(point, brushSize / 2, paint);
    }

    final picture = recorder.endRecording();
    final image = picture.toImage(size.width.toInt(), size.height.toInt());

    // Draw the scratched image
    image.then((img) {
      canvas.drawImage(img, Offset.zero, Paint());
    });

    // Add scratch lines for visual effect
    if (scratchPoints.length > 1) {
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = brushSize * 0.3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      for (var i = 0; i < scratchPoints.length - 1; i++) {
        canvas.drawLine(scratchPoints[i], scratchPoints[i + 1], linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ScratchPainter oldDelegate) {
    return oldDelegate.scratchPoints.length != scratchPoints.length;
  }
}
