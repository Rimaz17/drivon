import 'package:flutter/foundation.dart';

/// Who wrote a message in an Ask My Vehicle conversation.
enum ChatRole {
  user('USER'),
  assistant('ASSISTANT');

  const ChatRole(this.wireValue);

  final String wireValue;
}

/// One message of the conversation. A question that couldn't be answered
/// keeps its [error] until it is sent again.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.error,
  });

  final String id;
  final ChatRole role;
  final String text;

  /// Why the question wasn't answered (an AppException), or null.
  final Object? error;

  bool get failed => error != null;

  ChatMessage withError(Object? error) =>
      ChatMessage(id: id, role: role, text: text, error: error);

  @override
  bool operator ==(Object other) =>
      other is ChatMessage &&
      other.id == id &&
      other.role == role &&
      other.text == text &&
      other.error == error;

  @override
  int get hashCode => Object.hash(id, role, text, error);
}
