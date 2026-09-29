import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/haptic_manager.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/theme_res.dart';

class CustomToggle extends StatefulWidget {
  final RxBool isOn;
  final Function(bool value)? onChanged;

  const CustomToggle({super.key, required this.isOn, this.onChanged});

  @override
  State<CustomToggle> createState() => _CustomToggleState();
}

class _CustomToggleState extends State<CustomToggle> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onChanged != null
          ? () {
              final next = !widget.isOn.value;
              widget.isOn.value = next;
              widget.onChanged?.call(next);
              HapticManager.shared.light();
            }
          : () {},
      child: Obx(
        () => AnimatedContainer(
          height: 25,
          width: 37,
          decoration: ShapeDecoration(
              shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(cornerRadius: 30)),
              gradient: widget.isOn.value
                  ? StyleRes.themeGradient
                  : StyleRes.textLightGreyGradient()),
          alignment: widget.isOn.value
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 3),
          duration: const Duration(milliseconds: 300),
          child: Container(
              width: 20,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: whitePure(context))),
        ),
      ),
    );
  }
}
7