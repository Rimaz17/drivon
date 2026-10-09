import 'package:flutter/foundation.dart';

/// A file the user chose for upload, already in its final form (photos are
/// compressed), held in memory: documents are at most a few megabytes.
@immutable
class PickedFile {
  const PickedFile({
    required this.bytes,
    required this.contentType,
    required this.name,
  });

  final Uint8List bytes;

  /// MIME type, e.g. `image/jpeg` or `application/pdf`.
  final String contentType;

  /// Shown to the user only; the server never stores file names.
  final String name;

  int get sizeBytes => bytes.length;

  bool get isImage => contentType.startsWith('image/');
}

/// Why a file couldn't be used. The UI explains each case.
sealed class FilePickException implements Exception {
  const FilePickException();
}

/// The user turned off camera or photo access for Drivon.
final class FileAccessDeniedException extends FilePickException {
  const FileAccessDeniedException({required this.camera});

  /// True for the camera, false for the photo library.
  final bool camera;
}

/// The file is over the upload limit even after compression.
final class FileTooLargeException extends FilePickException {
  const FileTooLargeException(this.sizeBytes);

  final int sizeBytes;
}

/// The file couldn't be read or isn't the expected format.
final class UnreadableFileException extends FilePickException {
  const UnreadableFileException();
}
