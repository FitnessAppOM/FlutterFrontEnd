import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaTextField extends StatelessWidget {
  const TaqaTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.suffixIcon,
    this.onChanged,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
            fontSize: TaqaUiScale.sp(8),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.4,
            color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: TaqaUiScale.h(6)),
        Container(
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: TaqaUiScale.radius(10),
          ),
          padding: TaqaUiScale.insetsLTRB(14, 2, 10, 2),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onChanged: onChanged,
            maxLength: maxLength,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(14),
              fontWeight: FontWeight.w500,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              hintText: hint,
              counterText: '',
              suffixIcon: suffixIcon,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              hintStyle: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(14),
                fontWeight: FontWeight.w400,
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
