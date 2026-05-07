import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressUtil {
  /// Resize to max 1080px on the longest side, JPEG quality 65%.
  /// Target file size: 150 – 400 KB.
  static Future<File> compressAndResize(File source) async {
    final dir  = await getTemporaryDirectory();
    final path =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_receipt.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      path,
      quality: 65,
      minWidth: 1080,
      minHeight: 1920,
      format: CompressFormat.jpeg,
    );

    if (result == null) throw Exception('Gagal mengompresi gambar.');
    return File(result.path);
  }
}
