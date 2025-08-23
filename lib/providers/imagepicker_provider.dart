import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImagePickerProvider extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();

  /// Pick and compress an image from [source].
  /// Returns a compressed [File] on mobile. (Guard web separately if needed.)
  Future<File?> pickCompressedImage({
    ImageSource source = ImageSource.camera,
    int quality = 80,
    int minWidth = 1280,
    int minHeight = 720,
    double maxMb = 5.0,
  }) async {
    // 1) Pick image
    final XFile? photo = await _picker.pickImage(source: source);
    if (photo == null) return null;

    // NOTE: dart:io File is not supported on web
    if (kIsWeb) {
      // If you later need web support, handle bytes here
      // final bytes = await photo.readAsBytes();
      // return null; // or return a platform-agnostic value
      return null;
    }

    final file = File(photo.path);

    // 2) Temp target path
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(
      dir.path,
      "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg",
    );

    // 3) Compress
    final XFile? compressedX = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
    );

    if (compressedX == null) return file;

    // 4) Convert XFile → File
    final compressed = File(compressedX.path);

    // 5) Size check (simple guard)
    final sizeInMB = compressed.lengthSync() / (1024 * 1024);
    debugPrint("Compressed size: ${sizeInMB.toStringAsFixed(2)} MB");

    if (sizeInMB > maxMb) {
      final XFile? smallerX = await FlutterImageCompress.compressAndGetFile(
        compressed.path,
        targetPath, // overwrite same target
        quality: (quality * 0.75).clamp(10, 100).toInt(),
        minWidth: (minWidth * 0.8).toInt(),
        minHeight: (minHeight * 0.8).toInt(),
      );
      return smallerX != null ? File(smallerX.path) : compressed;
    }

    return compressed;
  }
}
