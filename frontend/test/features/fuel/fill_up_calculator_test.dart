import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:drivon/features/fuel/presentation/fill_up_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

FixedDecimal money(String text) => FixedDecimal.parse(text, scale: 2);
FixedDecimal litres(String text) => FixedDecimal.parse(text, scale: 3);

void main() {
  test('calculates the price per litre by default, as at the pump', () {
    final calculator = FillUpCalculator();

    expect(calculator.calculated, FillUpField.pricePerLitre);
    expect(
      calculator.calculate(litres: litres('30'), amount: money('10950')),
      money('365'),
    );
  });

  test('with a known price, litres follow from the amount', () {
    final calculator = FillUpCalculator()
      ..edited(FillUpField.pricePerLitre)
      ..edited(FillUpField.amount);

    expect(calculator.calculated, FillUpField.litres);
    expect(
      calculator.calculate(pricePerLitre: money('365'), amount: money('5000')),
      litres('13.699'),
    );
  });

  test('with a known price, the amount follows from the litres', () {
    final calculator = FillUpCalculator()
      ..edited(FillUpField.pricePerLitre)
      ..edited(FillUpField.litres);

    expect(calculator.calculated, FillUpField.amount);
    expect(
      calculator.calculate(
        litres: litres('30.123'),
        pricePerLitre: money('365'),
      ),
      money('10994.90'),
    );
  });

  test('typing into the calculated field hands calculation to another', () {
    final calculator = FillUpCalculator()..edited(FillUpField.pricePerLitre);

    // Amount and litres were the inputs; litres is now the oldest.
    expect(calculator.calculated, FillUpField.litres);
  });

  test('needs both other values above zero', () {
    final calculator = FillUpCalculator();

    expect(calculator.calculate(litres: litres('30')), isNull);
    expect(
      calculator.calculate(litres: litres('0'), amount: money('100')),
      isNull,
    );
  });
}
