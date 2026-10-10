import 'dart:async';

import 'package:drivon/features/assistant/data/assistant_api.dart';
import 'package:drivon/features/assistant/domain/chat_message.dart';

/// One question the fake received.
typedef AskedQuestion = ({
  String message,
  String? vehicleId,
  List<ChatMessage> history,
});

/// Answers questions from a script instead of the API.
class FakeAssistantApi implements AssistantApi {
  final List<AskedQuestion> asked = [];

  /// Each entry answers one question: a reply `String`, or an exception to
  /// throw. When empty, questions are echoed back.
  final List<Object> script = [];

  /// When set, the next question waits for it.
  Completer<void>? gate;

  @override
  Future<String> ask(
    String message, {
    required String? vehicleId,
    required List<ChatMessage> history,
  }) async {
    asked.add((message: message, vehicleId: vehicleId, history: history));
    final wait = gate;
    if (wait != null) {
      gate = null;
      await wait.future;
    }
    if (script.isEmpty) return 'Answer to: $message';
    final next = script.removeAt(0);
    if (next is Exception) throw next;
    return next as String;
  }
}
