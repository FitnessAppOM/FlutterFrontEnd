import 'package:flutter/material.dart';
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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "How To",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'InterTight',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: phWidth.clamp(170.0, 260.0),
                        height: phWidth.clamp(170.0, 260.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageProvider == null
                              ? const SizedBox.shrink()
                              : Image(image: imageProvider, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      exName,
                      style: const TextStyle(
                        fontFamily: 'InterTight',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      const Text(
                        "No instructions available.",
                        style: TextStyle(
                          fontFamily: 'InterTight',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          height: 1.45,
                        ),
                      )
                    else
                      ...rows.map((row) {
                        final idx = (row['index'] as int? ?? 0)
                            .toString()
                            .padLeft(2, '0');
                        final text = row['text']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text(
                                  "$idx.",
                                  style: const TextStyle(
                                    fontFamily: 'InterTight',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  text,
                                  style: const TextStyle(
                                    fontFamily: 'InterTight',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                    height: 1.45,
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
