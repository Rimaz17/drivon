import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drivon/core/network/storage_client.dart';
import 'package:drivon/core/services/picked_file.dart';
import 'package:drivon/features/documents/data/document_api.dart';
import 'package:drivon/features/documents/data/document_repository.dart';
import 'package:drivon/features/documents/domain/vehicle_document.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Map<String, Object?> documentJson({
  String id = 'doc-1',
  String status = 'ACTIVE',
  String? expiryDate = '2027-02-28',
}) => {
  'id': id,
  'vehicleId': 'vehicle-1',
  'type': 'INSURANCE',
  'issueDate': '2026-03-01',
  'expiryDate': expiryDate,
  'notes': 'Comprehensive',
  'contentType': 'image/jpeg',
  'sizeBytes': 4,
  'status': status,
  'createdAt': '2026-10-07T04:30:00Z',
  'updatedAt': '2026-10-07T04:30:00Z',
};

void main() {
  late FakeHttpAdapter api;
  late FakeHttpAdapter storage;
  late DocumentRepository repository;
  final responses = <String, ResponseBody Function()>{};
  const documents = '/api/v1/vehicles/vehicle-1/documents';
  final file = PickedFile(
    bytes: Uint8List.fromList([1, 2, 3, 4]),
    contentType: 'image/jpeg',
    name: 'policy.jpg',
  );
  const draft = DocumentDraft(
    type: DocumentType.insurance,
    notes: '  Comprehensive  ',
  );

  setUp(() {
    responses.clear();
    api = FakeHttpAdapter((request) async {
      final respond = responses['${request.method} ${request.uri.path}'];
      if (respond == null) throw StateError('Unexpected ${request.uri}');
      return respond();
    });
    storage = FakeHttpAdapter(
      (request) async => ResponseBody.fromString('', 200),
    );
    repository = DocumentRepository(
      DocumentApi(
        Dio(
          BaseOptions(
            baseUrl: 'http://api.test',
            headers: {'Authorization': 'Bearer access-token'},
          ),
        )..httpClientAdapter = api,
      ),
      StorageClient(Dio()..httpClientAdapter = storage),
      newId: () => 'doc-1',
    );
  });

  test('reads documents with optional dates', () async {
    responses['GET $documents'] = () => jsonBody(200, {
      'content': [documentJson(expiryDate: null)],
      'hasNext': false,
    });

    final page = await repository.list('vehicle-1', page: 0);

    final document = page.items.single;
    expect(document.type, DocumentType.insurance);
    expect(document.issueDate, DateTime(2026, 3));
    expect(document.expiryDate, isNull);
    expect(document.isPdf, isFalse);
  });

  test('uploads the file to storage between start and confirm', () async {
    responses['POST $documents'] = () => jsonBody(201, {
      'document': documentJson(status: 'PENDING'),
      'upload': {
        'url': 'https://storage.test/bucket/key?X-Amz-Signature=abc',
        'method': 'PUT',
        'headers': {'content-type': 'image/jpeg', 'content-length': '4'},
        'expiresAt': '2026-10-07T04:40:00Z',
      },
    });
    responses['POST $documents/doc-1/confirm'] = () =>
        jsonBody(200, documentJson());
    final progress = <double>[];

    final saved = await repository.upload(
      'vehicle-1',
      draft,
      file,
      id: repository.newDocumentId(),
      onProgress: progress.add,
    );

    expect(saved.id, 'doc-1');
    final start = api.requests.first;
    expect(start.data, {
      'id': 'doc-1',
      'type': 'INSURANCE',
      'issueDate': null,
      'expiryDate': null,
      'notes': 'Comprehensive',
      'contentType': 'image/jpeg',
      'sizeBytes': 4,
    });
    final put = storage.requests.single;
    expect(put.method, 'PUT');
    expect(put.uri.toString(), startsWith('https://storage.test/bucket/key'));
    expect(put.headers['content-type'], 'image/jpeg');
    expect(put.headers['content-length'], 4);
    // The API's token must never be sent to the storage service.
    expect(
      put.headers.keys.map((name) => name.toLowerCase()),
      isNot(contains('authorization')),
    );
    expect(api.requests.last.path, '$documents/doc-1/confirm');
  });

  test(
    'a finished upload is returned without sending the file again',
    () async {
      responses['POST $documents'] = () =>
          jsonBody(200, {'document': documentJson(), 'upload': null});

      final saved = await repository.upload(
        'vehicle-1',
        draft,
        file,
        id: 'doc-1',
      );

      expect(saved.id, 'doc-1');
      expect(storage.requests, isEmpty);
      expect(api.requests, hasLength(1));
    },
  );

  test('asks for documents expiring within 30 days', () async {
    responses['GET /api/v1/documents/expiring'] = () =>
        jsonBody(200, [documentJson()]);

    final expiring = await repository.expiringSoon();

    expect(expiring, hasLength(1));
    expect(api.requests.single.queryParameters, {'withinDays': 30});
  });

  test('reads a download link', () async {
    responses['GET $documents/doc-1/download-url'] = () => jsonBody(200, {
      'url': 'https://storage.test/bucket/key?X-Amz-Signature=def',
      'method': 'GET',
      'headers': <String, String>{},
      'expiresAt': '2026-10-07T04:35:00Z',
    });

    final url = await repository.fileUrl('vehicle-1', 'doc-1');

    expect(url.host, 'storage.test');
  });
}
