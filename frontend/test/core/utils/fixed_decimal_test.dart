import 'package:drivon/core/utils/fixed_decimal.dart';
import 'package:flutter_test/flutter_test.dart';

FixedDecimal money(String text) =>
    FixedDecimal.parse(text, scale: FixedDecimal.moneyScale);

FixedDecimal litres(String text) =>
    FixedDecimal.parse(text, scale: FixedDecimal.litresScale);

void main() {
  group('parsing', () {
    test('reads the API decimal strings exactly', () {
      expect(money('10950.50').units, 1095050);
      expect(money('10950').units, 1095000);
      expect(money('0.01').units, 1);
      expect(litres('30.125').units, 30125);
      expect(litres('30.5').units, 30500);
      expect(litres('30.').units, 30000);
    });

    test('ignores grouping commas and surrounding spaces', () {
      expect(money(' 18,500.00 ').units, 1850000);
    });

    test('rejects text, signs, extra fraction digits and huge values', () {
      for (final bad in [
        '',
        'abc',
        '-5',
        '+5',
        '1.2.3',
        '1e3',
        '.5',
        '1 000',
      ]) {
        expect(FixedDecimal.tryParse(bad, scale: 2), isNull, reason: '"$bad"');
      }
      expect(FixedDecimal.tryParse('10.505', scale: 2), isNull);
      expect(FixedDecimal.tryParse('9999999999999999', scale: 0), isNull);
      expect(
        () => FixedDecimal.parse('x', scale: 2),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('printing', () {
    test('writes plain strings for the API', () {
      expect(money('10950.5').toPlainString(), '10950.50');
      expect(money('0.05').toPlainString(), '0.05');
      expect(litres('7').toPlainString(), '7.000');
      expect(const FixedDecimal(42, 0).toPlainString(), '42');
    });

    test('trims trailing zeros for display', () {
      expect(litres('30.500').toTrimmedString(), '30.5');
      expect(litres('30.000').toTrimmedString(), '30');
      expect(money('100.00').toTrimmedString(), '100');
      expect(money('0.00').toTrimmedString(), '0');
    });
  });

  test('compares values across scales', () {
    expect(money('30.00'), litres('30.000'));
    expect(money('30.01').compareTo(litres('30.009')), greaterThan(0));
    expect(money('30.00').hashCode, litres('30').hashCode);
  });

  test('rounds division half up like the backend', () {
    expect(FixedDecimal.divideHalfUp(5, 2), 3);
    expect(FixedDecimal.divideHalfUp(4, 3), 1);
    expect(FixedDecimal.divideHalfUp(5, 3), 2);
    expect(FixedDecimal.divideHalfUp(0, 7), 0);
  });

  group('FuelMath', () {
    test('converts between litres, price and amount', () {
      expect(FuelMath.amount(litres('30'), money('365')), money('10950'));
      expect(FuelMath.litres(money('10950'), money('365')), litres('30'));
      expect(
        FuelMath.pricePerLitre(money('10950'), litres('30')),
        money('365'),
      );
    });

    test('rounds pump amounts to the cent', () {
      // 30.123 L × Rs. 365.00 = Rs. 10,994.895
      expect(
        FuelMath.amount(litres('30.123'), money('365')),
        money('10994.90'),
      );
      // Rs. 5,000 at Rs. 365.00 = 13.6986… L
      expect(FuelMath.litres(money('5000'), money('365')), litres('13.699'));
      // Rs. 3,694.90 for 10.123 L = Rs. 364.999…
      expect(
        FuelMath.pricePerLitre(money('3694.90'), litres('10.123')),
        money('365.00'),
      );
    });
  });
}
