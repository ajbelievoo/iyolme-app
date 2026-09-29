import 'package:flutter/material.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

class SVGAImageView extends StatefulWidget {
  final String url;
  final BoxFit fit;

  const SVGAImageView({super.key, required this.url, this.fit = BoxFit.cover});

  @override
  State<SVGAImageView> createState() => _SVGAImageViewState();
}

class _SVGAImageViewState extends State<SVGAImageView>
    with SingleTickerProviderStateMixin {
  late SVGAAnimationController animationController;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    animationController = SVGAAnimationController(vsync: this);
    _loadSVGA();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SVGAImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _loadSVGA();
    }
  }

  void _loadSVGA() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });
    try {
      final videoItem = await SVGAParser.shared.decodeFromURL(widget.url);
      if (mounted) {
        animationController.videoItem = videoItem;
        animationController
            .repeat(); // Start animation
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading SVGA: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return SVGAImage(animationController, fit: widget.fit);
  }
}
N