import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class CardioShareService {
  static Future<bool> ensurePhotoPermission() async {
    final photos = await Permission.photos.request();
    if (photos.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  static Future<Uint8List?> capturePng(
    RenderRepaintBoundary boundary, {
    double pixelRatio = 3.0,
  }) async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  static Future<Uint8List?> flattenPngOnBackground(
    Uint8List bytes,
    Color background, {
    double cornerRadius = 26,
  }) async {
    try {
      final image = await _decodeImage(bytes);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );
      final rect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));
      final paint = Paint()..color = background;
      canvas.drawRRect(rrect, paint);
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawImage(image, Offset.zero, Paint());
      canvas.restore();
      final picture = recorder.endRecording();
      final outImage = await picture.toImage(image.width, image.height);
      final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePngBytes(Uint8List bytes, {String name = 'cardio_achievement'}) async {
    await ImageGallerySaverPlus.saveImage(bytes, quality: 100, name: name);
  }

  static Future<void> sharePngBytes(
    BuildContext context,
    Uint8List bytes, {
    String text = 'Hey! Check out my latest cardio session on TaqaFitness.',
  }) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/cardio_achievement.png';
    final file = await File(filePath).writeAsBytes(bytes, flush: true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      sharePositionOrigin: origin,
    );
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    return completer.future;
  }
}
