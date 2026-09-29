import 'package:flutter/material.dart';

class AdsSkeletonCard extends StatelessWidget {
  const AdsSkeletonCard({
    super.key,
    this.height = 90,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
