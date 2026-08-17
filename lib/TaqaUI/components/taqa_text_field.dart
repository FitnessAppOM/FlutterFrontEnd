import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_pressable.dart';

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
    this.enabled = true,
    this.readOnly = false,
    this.inputFormatters,
    this.autofillHints,
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
  final bool enabled;
  final bool readOnly;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          taqaUppercase(label),
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
            enabled: enabled,
            readOnly: readOnly,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onChanged: onChanged,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            autofillHints: autofillHints,
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

/// Shared password visibility control used by Taqa authentication forms.
class TaqaPasswordVisibilityButton extends StatelessWidget {
  const TaqaPasswordVisibilityButton({
    super.key,
    required this.visible,
    required this.onTap,
  });

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TaqaPressable(
      semanticLabel: visible ? 'Hide password' : 'Show password',
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      pressedScale: 0.86,
      child: Padding(
        padding: TaqaUiScale.symmetric(horizontal: 4, vertical: 8),
        child: Icon(
          visible ? Icons.visibility_off : Icons.visibility,
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
          size: TaqaUiScale.w(18),
        ),
      ),
    );
  }
}
