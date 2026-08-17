import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Shared native share-sheet entry point.
///
/// Supplying a valid global origin is required for the iPad/macOS popover and
/// is harmless on iPhone and Android. Keeping it here prevents individual
/// screens from silently omitting that platform requirement.
class TaqaShareService {
  const TaqaShareService._();

  static Future<bool> shareText(
    BuildContext context, {
    required String text,
    String? subject,
  }) async {
    final result = await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: _shareOrigin(context),
    );
    return result.status != ShareResultStatus.unavailable;
  }

  static Future<bool> shareFilePaths(
    BuildContext context,
    List<String> paths, {
    String? text,
    String? subject,
  }) async {
    final result = await Share.shareXFiles(
      paths.map(XFile.new).toList(growable: false),
      text: text,
      subject: subject,
      sharePositionOrigin: _shareOrigin(context),
    );
    return result.status != ShareResultStatus.unavailable;
  }

  static Rect _shareOrigin(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final origin =
          renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (origin.width > 0 && origin.height > 0) return origin;
    }

    final screenSize = MediaQuery.maybeSizeOf(context) ?? const Size(1, 1);
    return Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: 1,
      height: 1,
    );
  }
}
