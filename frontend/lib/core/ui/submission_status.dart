import 'dart:async';

import 'package:flutter/widgets.dart';

/// Tracks a form submission: busy flag, the error to show, and whether the
/// request is slow enough to explain that the free server is waking up.
mixin SubmissionStatus<T extends StatefulWidget> on State<T> {
  static const Duration slowAfter = Duration(seconds: 5);

  bool busy = false;
  bool slow = false;
  String? error;
  Timer? _slowTimer;

  /// Runs [action]; on failure shows the text from [describe] (null shows
  /// no message, e.g. when the error was attached to a field instead).
  Future<void> submit(
    Future<void> Function() action, {
    required String? Function(Object error) describe,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      slow = false;
      error = null;
    });
    _slowTimer = Timer(slowAfter, () {
      if (mounted) setState(() => slow = true);
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) setState(() => error = describe(e));
    } finally {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() {
          busy = false;
          slow = false;
        });
      }
    }
  }

  /// Waits for the next frame so pending rebuilds (such as clearing
  /// server-side field errors shown with `forceErrorText`) reach the fields
  /// before they are validated; otherwise a stale error fails validation.
  /// Check `mounted` afterwards.
  Future<void> settleFields() => WidgetsBinding.instance.endOfFrame;

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }
}
