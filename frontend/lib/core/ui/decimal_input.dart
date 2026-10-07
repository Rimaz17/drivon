import 'package:flutter/services.dart';

/// Lets through only plain decimals with at most [maxWhole] digits before the
/// point and [maxFraction] after it, e.g. litres `999.999`. Edits that would
/// break the shape are ignored, so the field can never hold an invalid number
/// format (empty is allowed; validators require a value).
class DecimalTextInputFormatter extends TextInputFormatter {
  DecimalTextInputFormatter({required int maxWhole, required int maxFraction})
    : _pattern = RegExp(
        maxFraction == 0
            ? '^\\d{0,$maxWhole}\$'
            : '^\\d{0,$maxWhole}(\\.\\d{0,$maxFraction})?\$',
      );

  final RegExp _pattern;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}

/// Keyboard for decimals; iOS needs the decimal flag to show a point key.
const TextInputType decimalKeyboard = TextInputType.numberWithOptions(
  decimal: true,
);
