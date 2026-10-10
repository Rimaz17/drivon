import 'package:drivon/features/documents/domain/vehicle_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 7);

  VehicleDocument expiring(DateTime? expiry) => VehicleDocument(
    id: 'doc-1',
    vehicleId: 'vehicle-1',
    type: DocumentType.revenueLicence,
    contentType: DocumentContentTypes.pdf,
    sizeBytes: 1,
    expiryDate: expiry,
  );

  test('a document without an expiry date never expires', () {
    expect(expiring(null).expiryState(today), ExpiryState.none);
    expect(expiring(null).daysUntilExpiry(today), isNull);
  });

  test('is valid through its expiry date and expired the day after', () {
    expect(expiring(today).expiryState(today), ExpiryState.expiringSoon);
    expect(expiring(today).daysUntilExpiry(today), 0);
    expect(
      expiring(DateTime(2026, 10, 6)).expiryState(today),
      ExpiryState.expired,
    );
    expect(expiring(DateTime(2026, 10, 6)).daysUntilExpiry(today), -1);
  });

  test('expires soon within 30 days', () {
    expect(
      expiring(DateTime(2026, 11, 6)).expiryState(today),
      ExpiryState.expiringSoon,
    );
    expect(
      expiring(DateTime(2026, 11, 7)).expiryState(today),
      ExpiryState.valid,
    );
  });

  test('wire values round-trip', () {
    for (final type in DocumentType.values) {
      expect(DocumentType.fromWire(type.wireValue), type);
    }
    expect(() => DocumentType.fromWire('PASSPORT'), throwsFormatException);
  });
}
