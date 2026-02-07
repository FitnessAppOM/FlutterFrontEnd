import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_localizations.dart';
import '../services/diet/diet_service.dart';
import '../theme/app_theme.dart';

class DietPhotoEntrySheet extends StatefulWidget {
  const DietPhotoEntrySheet({
    super.key,
    required this.rootContext,
    required this.userId,
    required this.mealId,
    required this.mealTitle,
    this.trainingDayId,
    required this.onLogged,
  });

  /// Use a stable parent context (Scaffold) for SnackBars.
  /// Avoids RenderObject 'attached' assertions when the sheet is closing.
  final BuildContext rootContext;
  final int userId;
  final int mealId;
  final String mealTitle;
  final int? trainingDayId;
  final Future<void> Function(Map<String, dynamic>? daySummary) onLogged;

  @override
  State<DietPhotoEntrySheet> createState() => _DietPhotoEntrySheetState();
}

class _DietPhotoEntrySheetState extends State<DietPhotoEntrySheet> {
  static const int _maxBytes = 5 * 1024 * 1024; // 5MB
  static const Set<String> _allowedExt = {
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif',
    'webp',
  };

  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _photoBytes;
  String? _photoName;
  bool _loading = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_loading) return;
    final t = AppLocalizations.of(context);
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (!mounted || x == null) return;

      final name = (x.name.isNotEmpty ? x.name : 'meal.jpg').trim();
      final dot = name.lastIndexOf('.');
      final ext = (dot >= 0 ? name.substring(dot + 1) : '').toLowerCase();
      if (ext.isEmpty || !_allowedExt.contains(ext)) {
        if (widget.rootContext.mounted) {
          ScaffoldMessenger.of(widget.rootContext).showSnackBar(
            SnackBar(content: Text(t.translate("diet_photo_invalid_type"))),
          );
        }
        return;
      }

      final bytes = await x.readAsBytes();
      if (!mounted) return;

      if (bytes.isEmpty) {
        if (widget.rootContext.mounted) {
          ScaffoldMessenger.of(widget.rootContext).showSnackBar(
            SnackBar(content: Text(t.translate("diet_photo_empty"))),
          );
        }
        return;
      }

      if (bytes.length > _maxBytes) {
        if (widget.rootContext.mounted) {
          ScaffoldMessenger.of(widget.rootContext).showSnackBar(
            SnackBar(content: Text(t.translate("diet_photo_too_large"))),
          );
        }
        return;
      }

      setState(() {
        _photoBytes = bytes;
        _photoName = name;
      });
    } catch (_) {
      // ignore picker errors
    }
  }

  Future<void> _submit() async {
    if (_photoBytes == null) return;

    final t = AppLocalizations.of(context);
    setState(() => _loading = true);

    try {
      final res = await DietService.addItemFromPhoto(
        userId: widget.userId,
        mealId: widget.mealId,
        photoBytes: _photoBytes!,
        filename: _photoName ?? 'meal.jpg',
        textDescription: _descCtrl.text,
        trainingDayId: widget.trainingDayId,
      );

      if (!mounted) return;
      final daySummary = res["day_summary"] is Map
          ? (res["day_summary"] as Map).cast<String, dynamic>()
          : null;

      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(content: Text(t.translate("diet_item_added"))),
        );
      }

      // Capture before closing sheet so we don't use widget/context after pop
      final onLogged = widget.onLogged;
      final summary = daySummary;
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLogged(summary);
      });
    } catch (e) {
      if (!mounted) return;
      if (widget.rootContext.mounted) {
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          SnackBar(content: Text("${t.translate("diet_failed_to_add_item")}: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.88,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  height: 5,
                  width: 44,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.translate("diet_photo_title"),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loading ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.mealTitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : () => _pick(ImageSource.camera),
                                icon: const Icon(Icons.photo_camera),
                                label: Text(t.translate("diet_photo_take")),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: Colors.white24.withValues(alpha: 0.8)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library),
                                label: Text(t.translate("diet_photo_pick")),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: Colors.white24.withValues(alpha: 0.8)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_photoBytes != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.memory(
                                _photoBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextField(
                          controller: _descCtrl,
                          enabled: !_loading,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: t.translate("diet_photo_description_optional"),
                            labelStyle: const TextStyle(color: Colors.white70),
                            hintText: t.translate("diet_photo_description_hint"),
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: AppColors.cardDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t.translate("diet_photo_note"),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_loading || _photoBytes == null) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t.translate("diet_log")),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

