import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/uuid.dart';
import '../../auth/presentation/session_controller.dart';
import '../../vehicles/presentation/vehicles_controller.dart';
import '../data/assistant_api.dart';
import '../domain/chat_message.dart';

/// The conversation on the Ask My Vehicle screen.
@immutable
class ChatState {
  const ChatState({this.messages = const [], this.waiting = false});

  /// Oldest first.
  final List<ChatMessage> messages;

  /// True while a question is being answered.
  final bool waiting;
}

/// Sends questions with the recent conversation, so follow-ups make sense.
/// The conversation lives in memory only and is forgotten on sign-out.
class ChatController extends Notifier<ChatState> {
  /// Matches the server's limit on earlier turns sent with a question.
  static const int maxHistory = 10;

  /// Longest question the server accepts.
  static const int maxQuestionLength = 1000;

  @override
  ChatState build() {
    // A different user (or nobody) starts with an empty conversation.
    ref.watch(currentUserProvider.select((user) => user?.id));
    return const ChatState();
  }

  /// Asks [text] about the vehicle selected in the app.
  Future<void> send(String text) async {
    final question = text.trim();
    if (question.isEmpty || state.waiting) return;
    final message = ChatMessage(
      id: uuidV4(),
      role: ChatRole.user,
      text: question.length > maxQuestionLength
          ? question.substring(0, maxQuestionLength)
          : question,
    );
    final history = _history(state.messages);
    state = ChatState(messages: [...state.messages, message], waiting: true);
    await _ask(message, history);
  }

  /// Sends a question that failed again, with the conversation before it.
  Future<void> retry(String messageId) async {
    if (state.waiting) return;
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    final message = state.messages[index].withError(null);
    final history = _history(state.messages.sublist(0, index));
    state = ChatState(
      messages: [
        for (final (i, m) in state.messages.indexed)
          if (i == index) message else m,
      ],
      waiting: true,
    );
    await _ask(message, history);
  }

  void clear() {
    if (!state.waiting) state = const ChatState();
  }

  Future<void> _ask(ChatMessage message, List<ChatMessage> history) async {
    final vehicleId = ref.read(selectedVehicleProvider)?.id;
    try {
      final reply = await ref
          .read(assistantApiProvider)
          .ask(message.text, vehicleId: vehicleId, history: history);
      if (!ref.mounted) return;
      state = ChatState(
        messages: [
          ...state.messages,
          ChatMessage(id: uuidV4(), role: ChatRole.assistant, text: reply),
        ],
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      state = ChatState(
        messages: [
          for (final m in state.messages)
            if (m.id == message.id) m.withError(error) else m,
        ],
      );
    }
  }

  /// The latest answered turns: failed questions are left out, since they
  /// have no answer.
  static List<ChatMessage> _history(List<ChatMessage> messages) {
    final answered = [
      for (final m in messages)
        if (!m.failed) m,
    ];
    return answered.length <= maxHistory
        ? answered
        : answered.sublist(answered.length - maxHistory);
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
