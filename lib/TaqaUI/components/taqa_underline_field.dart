import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Bold section heading used to break up long forms (e.g. expert questionnaire).
class TaqaSectionHeading extends StatelessWidget {
  const TaqaSectionHeading({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(18),
          fontWeight: FontWeight.w700,
          color: TaqaUiColors.unnamedColor1c1d17,
        ),
      ),
    );
  }
}

/// Thin divider used to close out a section block.
class TaqaSectionDivider extends StatelessWidget {
  const TaqaSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: TaqaUiScale.h(16)),
      child: Divider(
        height: 1,
        thickness: 1,
        color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.12),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(4)),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(11),
          fontWeight: FontWeight.w400,
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

/// Plain underlined text field (label above, thin divider below) matching
/// the expert questionnaire mockup.
class TaqaUnderlineTextField extends StatelessWidget {
  const TaqaUnderlineTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.validator,
    this.onChanged,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(14),
      fontWeight: FontWeight.w500,
      color: TaqaUiColors.unnamedColor1c1d17,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) _FieldLabel(label: label!),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          inputFormatters: inputFormatters,
          style: textStyle,
          cursorColor: TaqaUiColors.unnamedColor1c1d17,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: TaqaUiScale.h(6)),
            hintText: hint,
            hintStyle: textStyle.copyWith(
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.35),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: TaqaUiColors.unnamedColorE93b3b),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: TaqaUiColors.unnamedColorE93b3b),
            ),
            errorStyle: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(10),
              color: TaqaUiColors.unnamedColorE93b3b,
            ),
          ),
        ),
      ],
    );
  }
}

/// Underlined dropdown matching [TaqaUnderlineTextField]'s visual language.
class TaqaUnderlineDropdown extends StatelessWidget {
  const TaqaUnderlineDropdown({
    super.key,
    this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.validator,
    this.hint = "Select",
    this.itemLabelBuilder,
  });

  final String? label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;
  final String? Function(String?)? validator;
  final String hint;
  final String Function(String)? itemLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(14),
      fontWeight: FontWeight.w500,
      color: TaqaUiColors.unnamedColor1c1d17,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) _FieldLabel(label: label!),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.5),
            size: TaqaUiScale.w(20),
          ),
          dropdownColor: TaqaUiColors.white,
          style: textStyle,
          validator: validator,
          hint: Text(
            hint,
            style: textStyle.copyWith(
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.35),
            ),
          ),
          items: options
              .map(
                (o) => DropdownMenuItem(
                  value: o,
                  child: Text(
                    itemLabelBuilder != null ? itemLabelBuilder!(o) : o,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: TaqaUiScale.h(6)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: TaqaUiColors.unnamedColor1c1d17),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: TaqaUiColors.unnamedColorE93b3b),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: TaqaUiColors.unnamedColorE93b3b),
            ),
            errorStyle: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(10),
              color: TaqaUiColors.unnamedColorE93b3b,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill-shaped choice used for both single- and multi-select groups
/// (black fill when selected, outline when not).
class TaqaPillChoice extends StatelessWidget {
  const TaqaPillChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? TaqaUiColors.unnamedColor1c1d17
          : TaqaUiColors.white,
      borderRadius: TaqaUiScale.radius(20),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(20),
        onTap: onTap,
        child: Container(
          padding: TaqaUiScale.insetsLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            borderRadius: TaqaUiScale.radius(20),
            border: selected
                ? null
                : Border.all(
                    color: TaqaUiColors.unnamedColor1c1d17.withValues(
                      alpha: 0.2,
                    ),
                  ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(12),
              fontWeight: FontWeight.w600,
              color: selected
                  ? TaqaUiColors.white
                  : TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
        ),
      ),
    );
  }
}

/// Row summarizing an uploaded file with an outline upload/capture button.
class TaqaUploadRow extends StatelessWidget {
  const TaqaUploadRow({
    super.key,
    required this.display,
    required this.actionLabel,
    required this.onTap,
  });

  final String display;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            display,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(14),
              fontWeight: FontWeight.w500,
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.55),
            ),
          ),
        ),
        SizedBox(width: TaqaUiScale.w(10)),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: TaqaUiScale.radius(5),
            onTap: onTap,
            child: Container(
              padding: TaqaUiScale.insetsLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                borderRadius: TaqaUiScale.radius(5),
                border: Border.all(color: TaqaUiColors.unnamedColor1c1d17),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_outlined,
                    size: TaqaUiScale.w(14),
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                  SizedBox(width: TaqaUiScale.w(4)),
                  Text(
                    actionLabel.toUpperCase(),
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(10),
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tappable summary row (e.g. Affiliation / Certification) with a value
/// on the left and a chevron affordance on the right.
class TaqaSummaryRow extends StatelessWidget {
  const TaqaSummaryRow({
    super.key,
    required this.value,
    this.onTap,
  });

  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: TaqaUiScale.h(4)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(14),
                    fontWeight: FontWeight.w500,
                    color: TaqaUiColors.unnamedColor1c1d17.withValues(
                      alpha: 0.55,
                    ),
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: TaqaUiColors.unnamedColor1c1d17.withValues(
                    alpha: 0.4,
                  ),
                  size: TaqaUiScale.w(20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red "Select at least one" style hint shown under unmet multi-select groups.
class TaqaRequiredHint extends StatelessWidget {
  const TaqaRequiredHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: TaqaUiScale.h(6)),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(11),
          color: TaqaUiColors.unnamedColorE93b3b,
        ),
      ),
    );
  }
}
