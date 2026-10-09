import 'dart:async';

import 'package:drivon/app/app.dart';
import 'package:drivon/app/router.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/services/file_picker_service.dart';
import 'package:drivon/core/services/picked_file.dart';
import 'package:drivon/core/services/url_opener.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/core/utils/date_format.dart';
import 'package:drivon/features/documents/domain/vehicle_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../vehicles/vehicle_test_doubles.dart';
import 'document_test_doubles.dart';

class _RecordingUrlOpener implements UrlOpener {
  final List<Uri> opened = [];

  @override
  Future<bool> openExternally(Uri url) async {
    opened.add(url);
    return true;
  }
}

void main() {
  late FakeDocumentApi documents;
  late FakeStorageClient storage;
  late FakeFilePickerService picker;
  late _RecordingUrlOpener opener;
  final now = today();

  Future<void> openDocuments(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: FakeVehicleApi([vehicleDto()]),
        documentApi: documents,
        storage: storage,
        filePicker: picker,
        extra: [urlOpenerProvider.overrideWithValue(opener)],
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const DrivonApp()),
    );
    await tester.pumpAndSettle();
    unawaited(
      container.read(routerProvider).push(AppRoutes.documentsPath('vehicle-1')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    // Lists build lazily, so scroll until the target exists, then into view.
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  setUp(() {
    documents = FakeDocumentApi();
    storage = FakeStorageClient();
    picker = FakeFilePickerService();
    opener = _RecordingUrlOpener();
  });

  testWidgets('invites the first document when none are stored', (
    tester,
  ) async {
    await openDocuments(tester);

    expect(find.text('Keep your papers here'), findsOneWidget);
    await tapAndSettle(tester, find.text('Add document'));
    expect(find.text('Take photo'), findsOneWidget);
  });

  testWidgets('puts the document needing attention first on the card', (
    tester,
  ) async {
    final soon = vehicleDocument(
      type: DocumentType.revenueLicence,
      expiryDate: now.add(const Duration(days: 5)),
    );
    final expired = vehicleDocument(
      id: 'doc-2',
      expiryDate: now.subtract(const Duration(days: 3)),
    );
    documents.documents.addAll([
      soon,
      expired,
      vehicleDocument(id: 'doc-3', type: DocumentType.receipt),
    ]);
    documents.expiringResponse = [expired, soon];
    await openDocuments(tester);

    expect(find.text('Insurance has expired'), findsOneWidget);
    expect(find.text('1 more document needs attention'), findsOneWidget);
    expect(find.text('Expires soon'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('No expiry date · PDF'), findsOneWidget);
  });

  testWidgets('adds a photo document and shows it in the list', (tester) async {
    documents.documents.add(vehicleDocument(type: DocumentType.receipt));
    await openDocuments(tester);
    await tapAndSettle(tester, find.text('Add document'));

    await tapAndSettle(tester, find.text('Take photo'));
    expect(picker.photoSources, [PhotoSource.camera]);
    expect(find.text('insurance.jpg'), findsOneWidget);
    await tapAndSettle(tester, find.text('Insurance'));
    await tapAndSettle(tester, find.text('Save document'));

    expect(storage.uploads, hasLength(1));
    expect(documents.confirmCalls, 1);
    expect(find.text('Document saved'), findsOneWidget);
    expect(find.text('Stored documents'), findsOneWidget);
    expect(find.text('Insurance'), findsOneWidget);
  });

  testWidgets('asks for a file and a type before uploading', (tester) async {
    documents.documents.add(vehicleDocument());
    await openDocuments(tester);
    await tapAndSettle(tester, find.text('Add document'));

    await tapAndSettle(tester, find.text('Save document'));

    expect(find.text('Add a photo or PDF of the document.'), findsOneWidget);
    expect(find.text('Choose a document type.'), findsOneWidget);
    expect(documents.startedIds, isEmpty);
  });

  testWidgets('explains denied camera access', (tester) async {
    documents.documents.add(vehicleDocument());
    picker.nextError = const FileAccessDeniedException(camera: true);
    await openDocuments(tester);
    await tapAndSettle(tester, find.text('Add document'));

    await tapAndSettle(tester, find.text('Take photo'));

    expect(find.textContaining("Drivon can't use the camera"), findsOneWidget);
  });

  testWidgets('saving again after a failed upload resumes the same document', (
    tester,
  ) async {
    documents.documents.add(vehicleDocument());
    documents.nextConfirmError = const ApiProblemException(
      statusCode: 422,
      code: ApiErrorCodes.uploadNotFound,
    );
    await openDocuments(tester);
    await tapAndSettle(tester, find.text('Add document'));
    await tapAndSettle(tester, find.text('Choose photo'));
    await tapAndSettle(tester, find.text('Registration'));

    await tapAndSettle(tester, find.text('Save document'));
    expect(
      find.text("The file didn't finish uploading. Save again to retry."),
      findsOneWidget,
    );

    await tapAndSettle(tester, find.text('Save document'));
    expect(documents.startedIds, hasLength(2));
    expect(documents.startedIds.toSet(), hasLength(1));
    expect(find.text('Document saved'), findsOneWidget);
  });

  testWidgets('opens a PDF in the phone viewer with a fresh link', (
    tester,
  ) async {
    documents.documents.add(
      vehicleDocument(expiryDate: now.add(const Duration(days: 200))),
    );
    await openDocuments(tester);
    await tapAndSettle(tester, find.text('Insurance'));

    expect(find.text('Valid'), findsOneWidget);
    await tapAndSettle(tester, find.text('Open PDF'));

    expect(opener.opened, [Uri.parse('https://storage.test/doc-1')]);
  });

  testWidgets('deletes a document after confirmation', (tester) async {
    documents.documents.add(vehicleDocument());
    await openDocuments(tester);
    await tapAndSettle(tester, find.text('Insurance'));

    await tapAndSettle(tester, find.byTooltip('Delete document'));
    await tapAndSettle(tester, find.text('Delete'));

    expect(documents.documents, isEmpty);
    expect(find.text('Document deleted'), findsOneWidget);
    expect(find.text('Keep your papers here'), findsOneWidget);
  });

  testWidgets('shows an error with a retry when the list fails', (
    tester,
  ) async {
    documents.listError = const NoConnectionException();
    await openDocuments(tester);

    expect(find.text("Couldn't load documents"), findsOneWidget);
    documents
      ..listError = null
      ..documents.add(vehicleDocument());
    await tapAndSettle(tester, find.text('Try again'));
    expect(find.text('Stored documents'), findsOneWidget);
  });
}
