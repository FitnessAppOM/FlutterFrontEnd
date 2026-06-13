import 'package:flutter/material.dart';
import 'package:taqaproject/TaqaUI/Typography/taqa_ui_typography.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import '../../services/training/training_service.dart';

class ExerciseInstructionDialog extends StatelessWidget {
  const ExerciseInstructionDialog({
    super.key,
    required this.title,
    required this.instructions,
    this.animationUrl,
  });

  final String title;
  final String instructions;
  final String? animationUrl;

  String _titleCase(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return "${lower[0].toUpperCase()}${lower.substring(1)}";
        })
        .join(' ');
  }

  List<Map<String, dynamic>> _instructionRows(String input) {
    final lines = input
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final out = <Map<String, dynamic>>[];
    var fallbackIndex = 1;
    final numbered = RegExp(r'^(\d+)\s*[\.\)\-:]?\s*(.*)$');
    for (final line in lines) {
      final match = numbered.firstMatch(line);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        final body = (match.group(2) ?? '').trim();
        if (parsed != null && body.isNotEmpty) {
          out.add({'index': parsed, 'text': body});
          fallbackIndex = parsed + 1;
          continue;
        }
      }
      var body = line;
      if (body.startsWith('- ') || body.startsWith('* ')) {
        body = body.substring(2).trim();
      }
      if (body.isEmpty) continue;
      out.add({'index': fallbackIndex, 'text': body});
      fallbackIndex += 1;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _instructionRows(instructions);
    final exName = _titleCase(title);
    final phWidth = MediaQuery.of(context).size.width * 0.52;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final resolvedImageUrl = TrainingService.animationImageUrl(
      animationUrl,
      null,
    );
    final imageProvider = resolvedImageUrl.isEmpty
        ? null
        : TrainingService.gifProvider(
            resolvedImageUrl,
            cacheWidth: (phWidth * dpr).round(),
            cacheHeight: (phWidth * dpr).round(),
          );

    return Scaffold(
      backgroundColor: const Color(0xFF1C1D17),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: TaqaUiScale.insetsLTRB(8, 8, 8, 2),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: TaqaUiScale.sp(20),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "How To",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 25 / 15,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: TaqaUiScale.sp(24),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: TaqaUiScale.insetsLTRB(17, 14, 17, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: TaqaUiScale.w(200),
                        height: TaqaUiScale.h(200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: TaqaUiScale.radius(5),
                        ),
                        child: ClipRRect(
                          borderRadius: TaqaUiScale.radius(5),
                          child: imageProvider == null
                              ? const SizedBox.shrink()
                              : Image(image: imageProvider, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(20)),
                    Text(
                      exName,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 25 / 15,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(10)),
                    if (rows.isEmpty)
                      Text(
                        "No instructions available.",
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(10),
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          height: 13 / 10,
                        ),
                      )
                    else
                      ...rows.map((row) {
                        final idx = (row['index'] as int? ?? 0)
                            .toString()
                            .padLeft(2, '0');
                        final text = row['text']?.toString() ?? '';
                        return Padding(
                          padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: TaqaUiScale.w(34),
                                child: Text(
                                  "$idx.",
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: TaqaUiScale.sp(10),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 13 / 10,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: TaqaUiScale.sp(10),
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                    height: 13 / 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
