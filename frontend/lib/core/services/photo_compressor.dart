import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'picked_file.dart';

/// Re-encodes a photo as a JPEG at [quality] (0–100), scaled so its shorter
/// side is at most [maxShortSide] pixels. Returns null if it can't be read.
typedef JpegEncoder =
    Future<Uint8List?> Function(
      String path, {
      required int quality,
      required int maxShortSide,
    });

/// Shrinks document photos before upload. Phone cameras produce 3–12 MB
/// images; a document stays readable at 1600 px on its shorter side as a
/// JPEG of a few hundred kilobytes. Quality steps down only if a photo is
/// still over [maxBytes]. Location and other EXIF data are dropped.
class PhotoCompressor {
  PhotoCompressor({JpegEncoder? encoder, this.maxBytes = defaultMaxBytes})
    : _encode = encoder ?? _flutterImageCompress;

  static const int defaultMaxBytes = 5 * 1024 * 1024;
  static const int maxShortSide = 1600;
  static const List<int> qualities = [80, 65, 50];

  final JpegEncoder _encode;
  final int maxBytes;

  /// The photo at [path] as JPEG bytes within [maxBytes]. Throws
  /// [UnreadableFileException] or [FileTooLargeException].
  Future<Uint8List> compress(String path) async {
    Uint8List? smallest;
    for (final quality in qualities) {
      final bytes = await _encode(
        path,
        quality: quality,
        maxShortSide: maxShortSide,
      );
      if (bytes == null || bytes.isEmpty) {
        throw const UnreadableFileException();
      }
      if (bytes.length <= maxBytes) return bytes;
      smallest = bytes;
    }
    throw FileTooLargeException(smallest!.length);
  }

  static Future<Uint8List?> _flutterImageCompress(
    String path, {
    required int quality,
    required int maxShortSide,
  }) => FlutterImageCompress.compressWithFile(
    path,
    // The plugin scales down until one side reaches these bounds, keeping
    // the aspect ratio, and never scales up.
    minWidth: maxShortSide,
    minHeight: maxShortSide,
    quality: quality,
    // JPEG output without EXIF (location, device) is the plugin's default.
  );
}
