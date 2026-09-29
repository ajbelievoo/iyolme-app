import 'package:flutter/material.dart';
import 'package:shortzz/utilities/theme_res.dart';

class AdsSectionHeader extends StatelessWidget {
  const AdsSectionHeader({
    super.key,
    required this.title,
    this.action,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textDarkGrey(context),
            ),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
