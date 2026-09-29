import 'package:flutter/material.dart';
import 'package:shortzz/utilities/theme_res.dart';

enum AdsTimeRange {
  days7,
  days30,
}

class AdsTimeRangeSwitch extends StatelessWidget {
  const AdsTimeRangeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AdsTimeRange value;
  final ValueChanged<AdsTimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedColor = themeAccentSolid(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(
            context,
            label: '7d',
            selected: value == AdsTimeRange.days7,
            selectedColor: selectedColor,
            onTap: () => onChanged(AdsTimeRange.days7),
          ),
          _pill(
            context,
            label: '30d',
            selected: value == AdsTimeRange.days30,
            selectedColor: selectedColor,
            onTap: () => onChanged(AdsTimeRange.days30),
          ),
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required bool selected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? selectedColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? selectedColor : textDarkGrey(context),
          ),
        ),
      ),
    );
  }
}
U