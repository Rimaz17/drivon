import 'package:drivon/core/services/file_picker_service.dart';
import 'package:drivon/core/services/photo_compressor.dart';
import 'package:drivon/core/services/picked_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' hide PickedFile;

Uint8List bytesOf(int length, {List<int> prefix = const []}) {
  final bytes = Uint8List(length);
  bytes.setRange(0, prefix.length, prefix);
  return bytes;
}

final pdfHeader = '%PDF-1.7'.codeUnits;

void main() {
  group('PhotoCompressor', () {
    test('keeps the first quality that fits', () async {
      final qualities = <int>[];
      final compressor = PhotoCompressor(
        maxBytes: 100,
        encoder: (path, {required quality, required maxShortSide}) async {
          qualities.add(quality);
          expect(maxShortSide, 1600);
          return bytesOf(quality == 80 ? 150 : 90);
        },
      );

      final bytes = await compressor.compress('photo.heic');

      expect(bytes, hasLength(90));
      expect(qualities, [80, 65]);
    });

    test('refuses a photo still too large at the lowest quality', () {
      final compressor = PhotoCompressor(
        maxBytes: 100,
        encoder: (path, {required quality, required maxShortSide}) async =>
            bytesOf(101 + quality),
      );

      expect(
        compressor.compress('photo.jpg'),
        throwsA(
          isA<FileTooLargeException>().having(
            (e) => e.sizeBytes,
            'sizeBytes',
            151,
          ),
        ),
      );
    });

    test('reports an image it can not read', () {
      final compressor = PhotoCompressor(
        encoder: (path, {required quality, required maxShortSide}) async =>
            null,
      );

      expect(
        compressor.compress('broken.jpg'),
        throwsA(isA<UnreadableFileException>()),
      );
    });
  });

  group('FilePickerService', () {
    final compressor = PhotoCompressor(
      encoder: (path, {required quality, required maxShortSide}) async =>
          bytesOf(10),
    );

    test('returns a compressed JPEG named after the photo', () async {
      final service = FilePickerService(
        pickPhoto: (source) async => XFile('IMG_0042.HEIC'),
        compressor: compressor,
      );

      final file = await service.pickPhoto(PhotoSource.camera);

      expect(file!.contentType, 'image/jpeg');
      expect(file.name, 'IMG_0042.jpg');
      expect(file.sizeBytes, 10);
    });

    test('returns null when the user cancels', () async {
      final service = FilePickerService(
        pickPhoto: (source) async => null,
        pickPdf: () async => null,
      );

      expect(await service.pickPhoto(PhotoSource.gallery), isNull);
      expect(await service.pickPdf(), isNull);
    });

    test('reports denied camera and photo access', () async {
      for (final (code, camera) in [
        ('camera_access_denied', true),
        ('photo_access_denied', false),
      ]) {
        final service = FilePickerService(
          pickPhoto: (source) async => throw PlatformException(code: code),
        );

        await expectLater(
          service.pickPhoto(PhotoSource.camera),
          throwsA(
            isA<FileAccessDeniedException>().having(
              (e) => e.camera,
              'camera',
              camera,
            ),
          ),
        );
      }
    });

    test('accepts a PDF within the limit', () async {
      final service = FilePickerService(
        pickPdf: () async =>
            XFile.fromData(bytesOf(2048, prefix: pdfHeader), path: 'cr.pdf'),
      );

      final file = await service.pickPdf();

      expect(file!.contentType, 'application/pdf');
      expect(file.name, 'cr.pdf');
      expect(file.sizeBytes, 2048);
    });

    test('refuses a PDF over 5 MB', () {
      final service = FilePickerService(
        pickPdf: () async => XFile.fromData(
          bytesOf(5 * 1024 * 1024 + 1, prefix: pdfHeader),
          path: 'scan.pdf',
        ),
      );

      expect(service.pickPdf(), throwsA(isA<FileTooLargeException>()));
    });

    test('refuses a file that is not really a PDF', () {
      final service = FilePickerService(
        pickPdf: () async => XFile.fromData(
          bytesOf(64, prefix: '<html>'.codeUnits),
          path: 'x.pdf',
        ),
      );

      expect(service.pickPdf(), throwsA(isA<UnreadableFileException>()));
    });
  });
}
