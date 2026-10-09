import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' hide PickedFile;

import 'photo_compressor.dart';
import 'picked_file.dart';

/// Where a document photo comes from.
enum PhotoSource { camera, gallery }

/// Opens the platform's camera, photo picker or file picker. Kept behind a
/// small seam because the plugins are platform code: tests replace these.
typedef PickPhoto = Future<XFile?> Function(PhotoSource source);
typedef PickPdf = Future<XFile?> Function();

/// Lets the user choose a document file and prepares it for upload: photos
/// are compressed to JPEG, PDFs are checked for size and format.
///
/// Permissions: the camera and the photo library ask on first use on iOS
/// (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`). Android
/// uses the system camera app and photo picker, which need no permission.
/// A denied permission throws [FileAccessDeniedException].
class FilePickerService {
  FilePickerService({
    PickPhoto? pickPhoto,
    PickPdf? pickPdf,
    PhotoCompressor? compressor,
  }) : _pickPhoto = pickPhoto ?? _imagePicker,
       _pickPdf = pickPdf ?? _fileSelector,
       _compressor = compressor ?? PhotoCompressor();

  final PickPhoto _pickPhoto;
  final PickPdf _pickPdf;
  final PhotoCompressor _compressor;

  /// A compressed JPEG of a new or existing photo, or null if cancelled.
  Future<PickedFile?> pickPhoto(PhotoSource source) async {
    final XFile? photo;
    try {
      photo = await _pickPhoto(source);
    } on PlatformException catch (error) {
      throw switch (error.code) {
        'camera_access_denied' => const FileAccessDeniedException(camera: true),
        'photo_access_denied' => const FileAccessDeniedException(camera: false),
        _ => const UnreadableFileException(),
      };
    }
    if (photo == null) return null;
    final bytes = await _compressor.compress(photo.path);
    return PickedFile(
      bytes: bytes,
      contentType: 'image/jpeg',
      name: _withExtension(photo.name, 'jpg'),
    );
  }

  /// A PDF chosen from the device's files, or null if cancelled. PDFs can't
  /// be compressed here, so one over the limit is refused.
  Future<PickedFile?> pickPdf() async {
    final file = await _pickPdf();
    if (file == null) return null;
    final size = await file.length();
    if (size > _compressor.maxBytes) throw FileTooLargeException(size);
    final bytes = await file.readAsBytes();
    if (!_looksLikePdf(bytes)) throw const UnreadableFileException();
    return PickedFile(
      bytes: bytes,
      contentType: 'application/pdf',
      name: file.name,
    );
  }

  /// Every PDF starts with `%PDF`.
  static bool _looksLikePdf(Uint8List bytes) =>
      bytes.length > 4 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;

  static String _withExtension(String name, String extension) {
    final dot = name.lastIndexOf('.');
    return '${dot > 0 ? name.substring(0, dot) : name}.$extension';
  }

  static Future<XFile?> _imagePicker(PhotoSource source) =>
      ImagePicker().pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        // The system photo picker then needs no library permission on iOS;
        // EXIF is dropped during compression anyway.
        requestFullMetadata: false,
      );

  static Future<XFile?> _fileSelector() => openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'],
        uniformTypeIdentifiers: ['com.adobe.pdf'],
      ),
    ],
  );
}

final filePickerServiceProvider = Provider<FilePickerService>(
  (ref) => FilePickerService(),
);
