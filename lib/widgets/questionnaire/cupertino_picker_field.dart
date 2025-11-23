import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: CupertinoPicker(
            itemExtent: 36,
            scrollController:
            FixedExtentScrollController(initialItem: selectedIndex),
            onSelectedItemChanged: (index) {
              setState(() => selectedIndex = index);
              widget.onSelected(widget.options[index]);
            },
            children: widget.options
                .map((e) => Center(child: Text(e)))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
