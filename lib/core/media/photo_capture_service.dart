import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the camera and returns a photograph small enough to actually send.
///
/// Downscaling happens at capture, not at upload, and that ordering matters: a
/// modern handset shoots 3-4 MB frames, and fifteen of those sitting on the
/// device waiting for signal is 50 MB of a phone that may not have it to spare.
/// Compressing first bounds both the wait and the storage.
///
/// The result is a copy in the app's own directory rather than the camera roll,
/// so a visit's evidence is not at the mercy of someone tidying their gallery.
class PhotoCaptureService {
  PhotoCaptureService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Long edge, in pixels. Enough to read a registration certificate or a
  /// passbook page; far less than the sensor produces.
  static const int maxDimension = 1600;

  /// Target ceiling. A JPEG of a document at 1600px is normally well under
  /// this; the quality ladder below exists for the ones that are not.
  static const int targetBytes = 500 * 1024;

  /// Captures and compresses, or returns null if the agent backs out.
  ///
  /// Never throws for an ordinary refusal — a denied camera permission or a
  /// cancelled capture is a normal thing to do, not an error state.
  Future<CapturedPhoto?> capture({ImageSource source = ImageSource.camera}) async {
    final XFile? shot;
    try {
      shot = await _picker.pickImage(
        source: source,
        // A first pass in the picker itself, so the full-resolution frame is
        // never fully decoded into memory on a low-end device.
        maxWidth: maxDimension.toDouble(),
        maxHeight: maxDimension.toDouble(),
        imageQuality: 85,
      );
    } catch (_) {
      return null;
    }
    if (shot == null) return null;

    return compressToTarget(shot.path);
  }

  /// Compresses a file down towards [targetBytes], stopping as soon as it fits.
  ///
  /// Steps down through quality rather than binary-searching: three attempts at
  /// most, each cheap, and the difference between quality 80 and 78 is not
  /// worth a fourth pass on a phone with a group waiting.
  Future<CapturedPhoto?> compressToTarget(String sourcePath) async {
    final directory = await _photoDirectory();
    final baseName = 'visit-${DateTime.now().millisecondsSinceEpoch}';

    for (final quality in const [80, 65, 50]) {
      final target = p.join(directory.path, '$baseName-q$quality.jpg');
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        target,
        quality: quality,
        minWidth: maxDimension,
        minHeight: maxDimension,
        format: CompressFormat.jpeg,
      );
      if (result == null) continue;

      final length = await File(result.path).length();
      if (length <= targetBytes || quality == 50) {
        return CapturedPhoto(
          path: result.path,
          fileName: '$baseName.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: length,
          capturedAt: DateTime.now(),
        );
      }
      // Too big still: drop this attempt before trying a lower quality, so a
      // failed ladder does not leave three copies on the device.
      await File(result.path).delete().catchError((_) => File(result.path));
    }

    return null;
  }

  Future<Directory> _photoDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, 'visit-photos'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}

class CapturedPhoto {
  const CapturedPhoto({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.capturedAt,
  });

  final String path;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// When the shutter fired, which is not when it reaches the server — often
  /// days apart in the field.
  final DateTime capturedAt;
}
