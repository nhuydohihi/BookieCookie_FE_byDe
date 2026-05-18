import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum ImageExportFormat { png, jpeg }

class AchievementShareService {
  const AchievementShareService._();

  static Future<Uint8List> captureWidget(
    RenderRepaintBoundary boundary, {
    required ImageExportFormat format,
    double pixelRatio = 3,
  }) async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Could not export achievement image.');
    }

    final pngBytes = byteData.buffer.asUint8List();
    if (format == ImageExportFormat.png) {
      return pngBytes;
    }

    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) {
      throw Exception('Could not encode achievement image as JPEG.');
    }

    return Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
  }

  static String extensionFor(ImageExportFormat format) {
    return format == ImageExportFormat.png ? 'png' : 'jpg';
  }

  static String mimeTypeFor(ImageExportFormat format) {
    return format == ImageExportFormat.png ? 'image/png' : 'image/jpeg';
  }

  static Future<File> writeTempImage({
    required Uint8List bytes,
    required String fileName,
    required ImageExportFormat format,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${tempDir.path}\\$safeFileName.${extensionFor(format)}');

    return file.writeAsBytes(bytes, flush: true);
  }

  static Future<void> saveToGallery({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final file = await writeTempImage(
      bytes: bytes,
      fileName: fileName,
      format: ImageExportFormat.png,
    );

    final result = await GallerySaver.saveImage(file.path, albumName: 'BookieCookie');
    if (result != true) {
      throw Exception('Could not save achievement image to gallery.');
    }
  }

  static Future<void> shareImage({
    required File file,
    required String text,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: _mimeTypeFromPath(file.path))],
        text: text,
      ),
    );
  }

  static String _mimeTypeFromPath(String path) {
    return path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
  }
}
