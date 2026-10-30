import 'package:clearport/app.dart';
import 'package:clearport/models/app_settings.dart';
import 'package:clearport/models/chat_message.dart';
import 'package:clearport/services/chat_api.dart';
import 'package:clearport/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends ChatApi {
  _FakeApi() : super(baseUrl: 'http://127.0.0.1:8080/v1');

  @override
  Future<ServerStatus> checkStatus({
    Duration timeout = const Duration(seconds: 5),
  }) async =>
      const ServerStatus(health: ServerHealth.online, model: 'test-model');

  @override
  Future<void> streamChat({
    required AppSettings settings,
    required List<ChatMessage> messages,
    required void Function(String delta) onDelta,
    CancelToken? token,
  }) async {
    for (final delta in ['Hello', ' from', ' the', ' test']) {
      onDelta(delta);
    }
  }
}

void main() {
  testWidgets('boots, sends a message and renders the streamed reply', (
    tester,
  ) async {
    final state = AppState(apiFactory: (_) => _FakeApi());
    await state.load();

    await tester.pumpWidget(ClearportApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Clearport'), findsOneWidget);
    expect(find.text('A quiet chat with your local models.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hi there');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Hi there'), findsNWidgets(2));
    expect(
      find.textContaining('Hello from the test', findRichText: true),
      findsOneWidget,
    );
    // Both the user prompt and assistant reply expose a copy action.
    expect(find.byIcon(Icons.copy_rounded), findsNWidgets(2));
  });

  testWidgets('shows an inline error when the server fails', (tester) async {
    final state = AppState(apiFactory: (_) => _FailingApi());
    await state.load();

    await tester.pumpWidget(ClearportApp(state: state));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

class _FailingApi extends ChatApi {
  _FailingApi() : super(baseUrl: 'http://127.0.0.1:8080/v1');

  @override
  Future<ServerStatus> checkStatus({
    Duration timeout = const Duration(seconds: 5),
  }) async => const ServerStatus(health: ServerHealth.offline);

  @override
  Future<void> streamChat({
    required AppSettings settings,
    required List<ChatMessage> messages,
    required void Function(String delta) onDelta,
    CancelToken? token,
  }) async {
    throw ChatApiException('Could not reach the server.');
  }
}
