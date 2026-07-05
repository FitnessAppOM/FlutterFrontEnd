import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';

class CupertinoPickerField extends StatefulWidget {
  final String label;
  final List<String> options;
  final Function(String) onSelected;
  final String initialValue;

  const CupertinoPickerField({
    super.key,
    required this.label,
    required this.options,
    required this.onSelected,
    required this.initialValue,
  });

  @override
  State<CupertinoPickerField> createState() => _CupertinoPickerFieldState();
}

class _CupertinoPickerFieldState extends State<CupertinoPickerField> {
  late int selectedIndex;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.options.indexOf(widget.initialValue);
    if (selectedIndex < 0) selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(11),
              fontWeight: FontWeight.w400,
              color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(4)),
          SizedBox(
            height: TaqaUiScale.h(150),
            child: CupertinoPicker(
              backgroundColor: Colors.transparent,
              itemExtent: TaqaUiScale.h(36),
              selectionOverlay: Container(
                decoration: BoxDecoration(
                  color: TaqaUiColors.unnamedColorE3e3e3,
                  borderRadius: TaqaUiScale.radius(8),
                ),
              ),
              scrollController:
              FixedExtentScrollController(initialItem: selectedIndex),
              onSelectedItemChanged: (index) {
                setState(() => selectedIndex = index);
                widget.onSelected(widget.options[index]);
              },
              children: widget.options
                  .map(
                    (e) => Center(
                      child: Text(
                        e,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(15),
                          fontWeight: FontWeight.w600,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
