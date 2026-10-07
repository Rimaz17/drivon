/// Fuels the API accepts. Wire values match the backend's `FuelType` enum.
enum FuelType {
  petrol('PETROL'),
  diesel('DIESEL'),
  hybrid('HYBRID');

  const FuelType(this.wireValue);

  final String wireValue;

  static FuelType fromWire(String value) => values.firstWhere(
    (type) => type.wireValue == value,
    orElse: () => throw FormatException('Unknown fuel type: $value'),
  );
}
