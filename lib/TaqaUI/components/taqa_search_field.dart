import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

/// Search bar used at the top of discovery-style TaqaUI screens.
class TaqaSearchField extends StatelessWidget {
  const TaqaSearchField({
    super.key,
    required this.controller,
    this.hint = 'Search',
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.taqaColors;
    return Container(
      width: double.infinity,
      height: TaqaUiScale.h(39),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TaqaUiScale.radius(15),
      ),
      padding: TaqaUiScale.insetsLTRB(14, 0, 10, 0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTapOutside: (_) {
          if (focusNode != null) {
            focusNode!.unfocus();
          } else {
            FocusScope.of(context).unfocus();
          }
        },
        textInputAction: TextInputAction.search,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
        minLines: 1,
        maxLines: 1,
        textAlignVertical: TextAlignVertical.center,
        scrollPadding: EdgeInsets.zero,
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(14),
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(14),
            fontWeight: FontWeight.w400,
            color: colors.textSecondary,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: TaqaUiScale.sp(18),
            color: colors.textSecondary,
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: TaqaUiScale.w(30),
            maxWidth: TaqaUiScale.w(30),
            minHeight: TaqaUiScale.h(39),
            maxHeight: TaqaUiScale.h(39),
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(
                    width: TaqaUiScale.w(30),
                    height: TaqaUiScale.h(39),
                  ),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close,
                    size: TaqaUiScale.sp(16),
                    color: colors.textSecondary,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                ),
          suffixIconConstraints: BoxConstraints(
            minWidth: TaqaUiScale.w(30),
            maxWidth: TaqaUiScale.w(30),
            minHeight: TaqaUiScale.h(39),
            maxHeight: TaqaUiScale.h(39),
          ),
        ),
      ),
    );
  }
}
