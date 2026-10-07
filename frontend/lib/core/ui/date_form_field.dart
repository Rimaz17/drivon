import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import '../utils/date_format.dart';

/// A date input that opens the platform's picker: the Material calendar on
/// Android, a Cupertino wheel in a bottom sheet on iOS. Dates run from
/// [firstDate] to [lastDate] inclusive.
class DateFormField extends FormField<DateTime> {
  DateFormField({
    required String label,
    required String doneLabel,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onChanged,
    super.initialValue,
    super.validator,
    super.enabled,
    String? errorText,
    String? helperText,
    super.key,
  }) : super(
         builder: (state) {
           final context = state.context;
           final value = state.value;
           Future<void> pick() async {
             final picked = await _pickDate(
               context,
               initial: value ?? lastDate,
               firstDate: firstDate,
               lastDate: lastDate,
               title: label,
               doneLabel: doneLabel,
             );
             if (picked != null) {
               state.didChange(picked);
               onChanged(picked);
             }
           }

           return Semantics(
             button: true,
             child: InkWell(
               onTap: state.widget.enabled ? pick : null,
               borderRadius: DrivonRadii.mdAll,
               child: InputDecorator(
                 isEmpty: value == null,
                 decoration: InputDecoration(
                   labelText: label,
                   helperText: helperText,
                   errorText: errorText ?? state.errorText,
                   enabled: state.widget.enabled,
                   suffixIcon: const Icon(Icons.calendar_today_outlined),
                 ),
                 child: value == null
                     ? null
                     : Text(
                         formatDate(context, value),
                         style: Theme.of(context).textTheme.bodyLarge,
                       ),
               ),
             ),
           );
         },
       );
}

/// The standard height of an iOS wheel picker.
const double _cupertinoPickerHeight = 216;

Future<DateTime?> _pickDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime firstDate,
  required DateTime lastDate,
  required String title,
  required String doneLabel,
}) {
  final clamped = initial.isAfter(lastDate)
      ? lastDate
      : initial.isBefore(firstDate)
      ? firstDate
      : initial;
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return _pickCupertino(
        context,
        initial: clamped,
        firstDate: firstDate,
        lastDate: lastDate,
        doneLabel: doneLabel,
      );
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return showDatePicker(
        context: context,
        initialDate: clamped,
        firstDate: firstDate,
        lastDate: lastDate,
        helpText: title,
      );
  }
}

Future<DateTime?> _pickCupertino(
  BuildContext context, {
  required DateTime initial,
  required DateTime firstDate,
  required DateTime lastDate,
  required String doneLabel,
}) {
  var selected = initial;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (popupContext) => Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: () => Navigator.of(popupContext).pop(selected),
                child: Text(doneLabel),
              ),
            ),
            SizedBox(
              height: _cupertinoPickerHeight,
              child: CupertinoTheme(
                data: const CupertinoThemeData(brightness: Brightness.dark),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  minimumDate: firstDate,
                  maximumDate: lastDate,
                  onDateTimeChanged: (date) => selected = today(date),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
