import 'package:flutter/material.dart';

class QuestionnaireSliderField extends StatefulWidget {
  final String label;
  final int min;
  final int max;
  final int initialValue;
  final ValueChanged<int> onChanged;

  const QuestionnaireSliderField({
    super.key,
    required this.label,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<QuestionnaireSliderField> createState() => _QuestionnaireSliderFieldState();
}

class _QuestionnaireSliderFieldState extends State<QuestionnaireSliderField> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${widget.label}: ${_value.toInt()}",
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        Slider(
          value: _value,
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          divisions: widget.max - widget.min,
          label: _value.toInt().toString(),
          onChanged: (val) {
            setState(() => _value = val);
            widget.onChanged(val.toInt());
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
