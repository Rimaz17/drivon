import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drivon/app/app.dart';
import 'package:drivon/core/errors/app_exception.dart';
import 'package:drivon/core/storage/token_store.dart';
import 'package:drivon/features/assistant/data/assistant_api.dart';
import 'package:drivon/features/assistant/domain/chat_message.dart';
import 'package:drivon/features/assistant/presentation/chat_controller.dart';
import 'package:drivon/features/auth/presentation/session_controller.dart';
import 'package:drivon/features/vehicles/presentation/vehicles_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';
import '../vehicles/vehicle_test_doubles.dart';
import 'assistant_test_doubles.dart';

void main() {
  late FakeAssistantApi assistant;

  setUp(() => assistant = FakeAssistantApi());

  ProviderContainer signedIn() {
    final container = ProviderContainer(
      overrides: testOverrides(
        tokens: InMemoryTokenStore(
          const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        ),
        vehicleApi: FakeVehicleApi([vehicleDto()]),
        assistantApi: assistant,
      ),
    );
    addTearDown(container.dispose);
    container.listen(chatControllerProvider, (_, _) {});
    return container;
  }

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await pumpEventQueue();
    }
  }

  group('ChatController', () {
    test('asks about the selected vehicle and keeps the answer', () async {
      final container = signedIn();
      await settle();
      await container.read(vehiclesControllerProvider.future);

      await container.read(chatControllerProvider.notifier).send(' Fuel? ');

      final chat = container.read(chatControllerProvider);
      expect(chat.waiting, isFalse);
      expect(chat.messages.map((m) => m.text), ['Fuel?', 'Answer to: Fuel?']);
      expect(chat.messages.map((m) => m.role), [
        ChatRole.user,
        ChatRole.assistant,
      ]);
      expect(assistant.asked.single.vehicleId, 'vehicle-1');
      expect(assistant.asked.single.history, isEmpty);
    });

    test('sends the latest ten answered turns for follow-ups', () async {
      final container = signedIn();
      await settle();
      final chat = container.read(chatControllerProvider.notifier);
      for (var i = 0; i < 6; i++) {
        await chat.send('Question $i');
      }

      await chat.send('Follow-up');

      final history = assistant.asked.last.history;
      expect(history, hasLength(ChatController.maxHistory));
      expect(history.first.text, 'Question 1');
      expect(history.last.text, 'Answer to: Question 5');
    });

    test(
      'a failed question can be sent again and is left out of history',
      () async {
        assistant.script.add(
          const ApiProblemException(
            statusCode: 503,
            code: ApiErrorCodes.assistantUnavailable,
          ),
        );
        final container = signedIn();
        await settle();
        final chat = container.read(chatControllerProvider.notifier);

        await chat.send('Fuel?');
        final failed = container.read(chatControllerProvider).messages.single;
        expect(failed.failed, isTrue);

        await chat.send('Other');
        expect(assistant.asked.last.history, isEmpty);

        await chat.retry(failed.id);
        final messages = container.read(chatControllerProvider).messages;
        expect(messages.first.failed, isFalse);
        expect(messages.last.text, 'Answer to: Fuel?');
        expect(assistant.asked.last.history, isEmpty);
      },
    );

    test(
      'ignores blank questions and a second question while waiting',
      () async {
        final container = signedIn();
        await settle();
        final chat = container.read(chatControllerProvider.notifier);
        final gate = Completer<void>();
        assistant.gate = gate;

        final first = chat.send('One');
        await chat.send('Two');
        await chat.send('   ');
        gate.complete();

        expect(container.read(chatControllerProvider).waiting, isTrue);
        await first;
        expect(assistant.asked.map((q) => q.message), ['One']);
      },
    );

    test('signing out forgets the conversation', () async {
      final container = signedIn();
      await settle();
      await container.read(chatControllerProvider.notifier).send('Fuel?');

      await container.read(sessionControllerProvider.notifier).signOut();
      await settle();

      expect(container.read(chatControllerProvider).messages, isEmpty);
    });
  });

  test('the API sends the question, vehicle and history', () async {
    final adapter = FakeHttpAdapter(
      (request) async => jsonBody(200, {'reply': 'Rs. 18,500.'}),
    );
    final api = AssistantApi(
      Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter,
    );

    final reply = await api.ask(
      'And August?',
      vehicleId: 'vehicle-1',
      history: [
        const ChatMessage(id: '1', role: ChatRole.user, text: 'Fuel?'),
        ChatMessage(id: '2', role: ChatRole.assistant, text: 'x' * 5000),
      ],
    );

    expect(reply, 'Rs. 18,500.');
    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect(adapter.requests.single.uri.path, '/api/v1/assistant/chat');
    expect(body['message'], 'And August?');
    expect(body['vehicleId'], 'vehicle-1');
    final history = (body['history'] as List).cast<Map<String, dynamic>>();
    expect(jsonEncode(history.first), '{"role":"USER","text":"Fuel?"}');
    expect((history.last['text'] as String).length, AssistantApi.maxTurnLength);
  });

  group('AssistantScreen', () {
    Future<void> openChat(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1236, 2745);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: testOverrides(
          tokens: InMemoryTokenStore(
            const AuthTokens(accessToken: 'a', refreshToken: 'r'),
          ),
          vehicleApi: FakeVehicleApi([vehicleDto()]),
          assistantApi: assistant,
        ),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DrivonApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ask My Vehicle'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers example questions about the selected vehicle', (
      tester,
    ) async {
      await openChat(tester);

      expect(find.textContaining('Ask about your Toyota Aqua'), findsOneWidget);
      await tester.tap(find.text("What's my average km/L?"));
      await tester.pumpAndSettle();

      expect(find.text("What's my average km/L?"), findsOneWidget);
      expect(find.text("Answer to: What's my average km/L?"), findsOneWidget);
    });

    testWidgets('sends a typed question and shows a failure with retry', (
      tester,
    ) async {
      assistant.script.add(
        const ApiProblemException(
          statusCode: 422,
          code: ApiErrorCodes.assistantIncomplete,
        ),
      );
      await openChat(tester);

      await tester.enterText(find.byType(TextField), 'Compare everything');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "I couldn't work that out. Try asking in a simpler way, one thing at a time.",
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Answer to: Compare everything'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);

      await tester.tap(find.byTooltip('Start over'));
      await tester.pumpAndSettle();
      expect(find.text('Try asking'), findsOneWidget);
    });

    testWidgets('the garage opens Ask My Vehicle from its tile too', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1236, 2745);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(
            tokens: InMemoryTokenStore(
              const AuthTokens(accessToken: 'a', refreshToken: 'r'),
            ),
            vehicleApi: FakeVehicleApi([vehicleDto()]),
            assistantApi: assistant,
          ),
          child: const DrivonApp(),
        ),
      );
      await tester.pumpAndSettle();
      final tile = find.text('Ask about fuel, services and costs');
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.text('Try asking'), findsOneWidget);
    });
  });
}
