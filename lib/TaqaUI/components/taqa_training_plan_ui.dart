import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_outline_tag_button.dart';

class TaqaTrainingDaySection extends StatelessWidget {
  const TaqaTrainingDaySection({
    super.key,
    required this.dayNumber,
    required this.dayName,
    required this.enabled,
    required this.onDayNameChanged,
    required this.exercises,
    required this.onAddExercise,
    this.onDelete,
  });

  final int dayNumber;
  final String dayName;
  final bool enabled;
  final ValueChanged<String> onDayNameChanged;
  final List<Widget> exercises;
  final VoidCallback? onAddExercise;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: TaqaUiScale.h(20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Day $dayNumber',
                  style: TextStyle(
                    color: TaqaUiColors.charcoal,
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    fontWeight: FontWeight.w700,
                    height: 25 / 15,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (onDelete != null)
                TaqaOutlineTagButton(
                  label: 'Delete',
                  width: TaqaUiScale.w(43),
                  height: TaqaUiScale.h(20),
                  onTap: enabled ? onDelete : null,
                ),
            ],
          ),
        ),
        SizedBox(height: TaqaUiScale.h(4)),
        TaqaTrainingDayNameField(
          initialValue: dayName,
          enabled: enabled,
          onChanged: onDayNameChanged,
        ),
        SizedBox(height: TaqaUiScale.h(15)),
        ...exercises,
        TaqaOutlineTagButton(
          label: '+ Add Exercise',
          width: TaqaUiScale.w(100),
          height: TaqaUiScale.h(20),
          onTap: enabled ? onAddExercise : null,
        ),
      ],
    );
  }
}

class TaqaTrainingDayNameField extends StatelessWidget {
  const TaqaTrainingDayNameField({
    super.key,
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });

  final String initialValue;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TaqaUiScale.h(25),
      child: TextFormField(
        initialValue: initialValue,
        enabled: enabled,
        cursorColor: TaqaUiColors.charcoal,
        textInputAction: TextInputAction.done,
        style: TextStyle(
          color: TaqaUiColors.charcoal,
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(15),
          fontWeight: FontWeight.w400,
          height: 25 / 15,
          letterSpacing: 0,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: TaqaUiColors.charcoal, width: 0.5),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: TaqaUiColors.charcoal, width: 0.5),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: TaqaUiColors.charcoal, width: 0.5),
          ),
          disabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: TaqaUiColors.charcoal, width: 0.5),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
        onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }
}

class TaqaTrainingExerciseCard extends StatelessWidget {
  const TaqaTrainingExerciseCard({
    super.key,
    required this.exerciseName,
    required this.onExerciseTap,
    required this.metricFields,
    this.onDelete,
  });

  final String exerciseName;
  final VoidCallback? onExerciseTap;
  final List<Widget> metricFields;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: TaqaUiScale.h(133)),
      margin: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
      padding: TaqaUiScale.insetsLTRB(14, 10, 13, 10),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: TaqaUiScale.h(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Exercise',
                    style: TextStyle(
                      color: TaqaUiColors.charcoal,
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(10),
                      fontWeight: FontWeight.w700,
                      height: 12 / 10,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (onDelete != null)
                  Transform.translate(
                    offset: Offset(0, -TaqaUiScale.h(3)),
                    child: TaqaTrainingRemoveIcon(onTap: onDelete!),
                  ),
              ],
            ),
          ),
          SizedBox(height: TaqaUiScale.h(2)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onExerciseTap,
              borderRadius: TaqaUiScale.radius(5),
              child: Container(
                width: double.infinity,
                height: TaqaUiScale.h(21),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: TaqaUiColors.charcoal,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Text(
                  exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: TaqaUiColors.charcoal,
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    fontWeight: FontWeight.w400,
                    height: 21 / 15,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(11)),
          Row(
            children: List<Widget>.generate(metricFields.length, (index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: index == metricFields.length - 1
                        ? 0
                        : TaqaUiScale.w(9),
                  ),
                  child: metricFields[index],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class TaqaTrainingRemoveIcon extends StatelessWidget {
  const TaqaTrainingRemoveIcon({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Remove exercise',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: TaqaUiScale.w(8),
          height: TaqaUiScale.h(8),
          child: CustomPaint(painter: const _TaqaTrainingRemoveIconPainter()),
        ),
      ),
    );
  }
}

class _TaqaTrainingRemoveIconPainter extends CustomPainter {
  const _TaqaTrainingRemoveIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1F1F1F)
      ..strokeWidth = TaqaUiScale.w(1.2)
      ..strokeCap = StrokeCap.square;
    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TaqaTrainingMetricField extends StatelessWidget {
  const TaqaTrainingMetricField({
    super.key,
    required this.label,
    required this.controller,
    required this.enabled,
    required this.keyboardType,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TaqaUiScale.h(39),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: TaqaUiColors.charcoal,
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(10),
              fontWeight: FontWeight.w700,
              height: 12 / 10,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(3)),
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              cursorColor: TaqaUiColors.charcoal,
              keyboardType: keyboardType,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                color: TaqaUiColors.charcoal,
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w400,
                height: 21 / 15,
                letterSpacing: 0,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: TaqaUiColors.charcoal,
                    width: 0.5,
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: TaqaUiColors.charcoal,
                    width: 0.5,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: TaqaUiColors.charcoal,
                    width: 0.5,
                  ),
                ),
                disabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: TaqaUiColors.charcoal,
                    width: 0.5,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
        ],
      ),
    );
  }
}

class TaqaTrainingMetricValue extends StatelessWidget {
  const TaqaTrainingMetricValue({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TaqaUiScale.h(39),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: TaqaUiColors.charcoal,
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(10),
              fontWeight: FontWeight.w700,
              height: 12 / 10,
            ),
          ),
          SizedBox(height: TaqaUiScale.h(3)),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: TaqaUiColors.charcoal, width: 0.5),
                ),
              ),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: TaqaUiColors.charcoal,
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(15),
                  fontWeight: FontWeight.w400,
                  height: 21 / 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TaqaTrainingNumberInput extends StatefulWidget {
  const TaqaTrainingNumberInput({
    super.key,
    required this.label,
    required this.initialValue,
    required this.minValue,
    required this.maxValue,
    required this.enabled,
    required this.onChanged,
    this.allowNull = false,
  });

  final String label;
  final int? initialValue;
  final int minValue;
  final int maxValue;
  final bool enabled;
  final bool allowNull;
  final ValueChanged<int?> onChanged;

  @override
  State<TaqaTrainingNumberInput> createState() =>
      _TaqaTrainingNumberInputState();
}

class _TaqaTrainingNumberInputState extends State<TaqaTrainingNumberInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue == null ? '' : '${widget.initialValue}',
    );
  }

  @override
  void didUpdateWidget(covariant TaqaTrainingNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _controller.text = widget.initialValue == null
          ? ''
          : '${widget.initialValue}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChange(String raw) {
    final text = raw.trim();
    if (text.isEmpty && widget.allowNull) {
      widget.onChanged(null);
      return;
    }
    final parsed = int.tryParse(text);
    if (parsed == null) return;
    final clamped = parsed.clamp(widget.minValue, widget.maxValue);
    if (clamped != parsed) {
      _controller.text = '$clamped';
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return TaqaTrainingMetricField(
      label: widget.label,
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      onChanged: _handleChange,
    );
  }
}

class TaqaTrainingWeightInput extends StatefulWidget {
  const TaqaTrainingWeightInput({
    super.key,
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });

  final double? initialValue;
  final bool enabled;
  final ValueChanged<double?> onChanged;

  @override
  State<TaqaTrainingWeightInput> createState() =>
      _TaqaTrainingWeightInputState();
}

class _TaqaTrainingWeightInputState extends State<TaqaTrainingWeightInput> {
  static const double _maxWeight = 1000;
  late final TextEditingController _controller;

  String _format(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.initialValue));
  }

  @override
  void didUpdateWidget(covariant TaqaTrainingWeightInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _toDouble(_controller.text) != widget.initialValue) {
      _controller.text = _format(widget.initialValue);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _toDouble(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  void _handleChange(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      widget.onChanged(null);
      return;
    }
    final parsed = double.tryParse(text);
    if (parsed == null) return;
    if (parsed < 0) {
      widget.onChanged(0);
      return;
    }
    if (parsed > _maxWeight) {
      _controller.text = _format(_maxWeight);
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      widget.onChanged(_maxWeight);
      return;
    }
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TaqaTrainingMetricField(
      label: 'Weight',
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: _handleChange,
    );
  }
}
