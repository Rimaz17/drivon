import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/chat_message.dart';

/// Asks the Drivon API's assistant. Throws AppExceptions.
class AssistantApi {
  AssistantApi(this._dio);

  final Dio _dio;

  /// Longest earlier turn the server accepts.
  static const int maxTurnLength = 4000;

  /// The answer to [message] about [vehicleId], with the earlier [history]
  /// (oldest first) for follow-up questions.
  Future<String> ask(
    String message, {
    required String? vehicleId,
    required List<ChatMessage> history,
  }) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/assistant/chat',
      data: {
        'message': message,
        'vehicleId': vehicleId,
        'history': [
          for (final turn in history)
            {
              'role': turn.role.wireValue,
              'text': turn.text.length > maxTurnLength
                  ? turn.text.substring(0, maxTurnLength)
                  : turn.text,
            },
        ],
      },
    );
    return response.data!['reply'] as String;
  });
}

final assistantApiProvider = Provider<AssistantApi>(
  (ref) => AssistantApi(ref.watch(dioProvider)),
);
