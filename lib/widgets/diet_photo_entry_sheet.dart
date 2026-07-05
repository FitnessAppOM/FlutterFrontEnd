import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_localizations.dart';
import '../services/diet/diet_service.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

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
          AppToast.show(
            widget.rootContext,
            t.translate("diet_photo_invalid_type"),
            type: AppToastType.error,
          );
        }
        return;
      }

      final bytes = await x.readAsBytes();
      if (!mounted) return;

      if (bytes.isEmpty) {
        if (widget.rootContext.mounted) {
          AppToast.show(
            widget.rootContext,
            t.translate("diet_photo_empty"),
            type: AppToastType.error,
          );
        }
        return;
      }

      if (bytes.length > _maxBytes) {
        if (widget.rootContext.mounted) {
          AppToast.show(
            widget.rootContext,
            t.translate("diet_photo_too_large"),
            type: AppToastType.error,
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
        AppToast.show(
          widget.rootContext,
          t.translate("diet_item_added"),
          type: AppToastType.success,
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
        AppToast.show(
          widget.rootContext,
          "${t.translate("diet_failed_to_add_item")}: $e",
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.88,
          child: Padding(
            padding: TaqaUiScale.insetsLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Container(
                  height: 5,
                  width: 44,
                  margin: EdgeInsets.only(bottom: TaqaUiScale.h(16)),
                  decoration: BoxDecoration(
                    color: TaqaUiColors.unnamedColor1c1d17.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      t.translate("diet_photo_title"),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w700,
                        height: 25 / 15,
                        letterSpacing: 0,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _PhotoSourceButton(
                                icon: Icons.photo_camera,
                                label: t.translate("diet_photo_take"),
                                onTap: _loading
                                    ? null
                                    : () => _pick(ImageSource.camera),
                              ),
                            ),
                            SizedBox(width: TaqaUiScale.w(12)),
                            Expanded(
                              child: _PhotoSourceButton(
                                icon: Icons.photo_library,
                                label: t.translate("diet_photo_pick"),
                                onTap: _loading
                                    ? null
                                    : () => _pick(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),
                        if (_photoBytes != null) ...[
                          SizedBox(height: TaqaUiScale.h(12)),
                          ClipRRect(
                            borderRadius: TaqaUiScale.radius(15),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.memory(
                                _photoBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: TaqaUiScale.h(12)),
                        Container(
                          width: double.infinity,
                          padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
                          decoration: BoxDecoration(
                            color: TaqaUiColors.white,
                            borderRadius: TaqaUiScale.radius(15),
                            border: Border.all(
                              color: TaqaUiColors.unnamedColor1c1d17.withValues(
                                alpha: 0.10,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.translate("diet_photo_description_optional"),
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(15),
                                  fontWeight: FontWeight.w700,
                                  height: 25 / 15,
                                  letterSpacing: 0,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              ),
                              SizedBox(height: TaqaUiScale.h(8)),
                              TextField(
                                controller: _descCtrl,
                                enabled: !_loading,
                                maxLines: 3,
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(15),
                                  fontWeight: FontWeight.w400,
                                  height: 21 / 15,
                                  letterSpacing: 0,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                                decoration: _borderlessFieldDecoration(
                                  hintText: t.translate(
                                    "diet_photo_description_hint",
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: TaqaUiScale.h(10)),
                        Text(
                          t.translate("diet_photo_note"),
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(12),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            color: TaqaUiColors.unnamedColor1c1d17.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(16)),
                Material(
                  color: _photoBytes == null
                      ? TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.12)
                      : TaqaUiColors.unnamedColorE4e93b,
                  borderRadius: TaqaUiScale.radius(5),
                  child: InkWell(
                    borderRadius: TaqaUiScale.radius(5),
                    onTap: (_loading || _photoBytes == null) ? null : _submit,
                    child: SizedBox(
                      width: double.infinity,
                      height: TaqaUiScale.h(45),
                      child: Center(
                        child: _loading
                            ? SizedBox(
                                height: TaqaUiScale.h(18),
                                width: TaqaUiScale.w(18),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              )
                            : Text(
                                t.translate("diet_log").toUpperCase(),
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(10),
                                  fontWeight: FontWeight.w700,
                                  height: 12 / 10,
                                  letterSpacing: 0,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              ),
                      ),
                    ),
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

InputDecoration _borderlessFieldDecoration({String? hintText}) {
  return InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.zero,
    hintText: hintText,
    hintStyle: TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(15),
      fontWeight: FontWeight.w400,
      height: 21 / 15,
      letterSpacing: 0,
      color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.3),
    ),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );
}

class _PhotoSourceButton extends StatelessWidget {
  const _PhotoSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: TaqaUiScale.radius(15),
      onTap: onTap,
      child: Container(
        height: TaqaUiScale.h(45),
        decoration: BoxDecoration(
          color: TaqaUiColors.white,
          borderRadius: TaqaUiScale.radius(15),
          border: Border.all(
            color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: TaqaUiScale.w(18),
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
            SizedBox(width: TaqaUiScale.w(8)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(13),
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
