import 'package:clearport/screens/settings_screen.dart';
import 'package:clearport/services/chat_api.dart';
import 'package:clearport/state/app_state.dart';
import 'package:clearport/theme.dart';
import 'package:clearport/widgets/app_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ModelsApi extends ChatApi {
  _ModelsApi(this.models) : super(baseUrl: 'http://127.0.0.1:8080/v1');

  final List<String> models;

  @override
  Future<ServerStatus> checkStatus({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (models.isEmpty) {
      return const ServerStatus(
        health: ServerHealth.reachable,
        issue: ServerIssue.noModels,
        message: 'The server responded, but it did not report any models.',
      );
    }
    return ServerStatus(
      health: ServerHealth.online,
      models: models,
      model: models.first,
    );
  }
}

Widget _app(AppState state) => AppScope(
  state: state,
  child: MaterialApp(theme: AppTheme.dark(), home: const SettingsScreen()),
);

void main() {
  testWidgets('a model reported by the server can be picked', (tester) async {
    final state = AppState(
      apiFactory: (_) => _ModelsApi(['gemma-3-1b-it', 'qwen2.5-1.5b']),
    );
    await state.load();

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();

    expect(find.text('Available on the server'), findsOneWidget);

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(find.text('gemma-3-1b-it'), findsOneWidget);
    expect(find.text('qwen2.5-1.5b'), findsOneWidget);

    await tester.tap(find.text('qwen2.5-1.5b'));
    await tester.pumpAndSettle();

    expect(state.settings.model, 'qwen2.5-1.5b');
  });

  testWidgets('an empty model list leaves manual entry in place', (
    tester,
  ) async {
    final state = AppState(apiFactory: (_) => _ModelsApi(const []));
    await state.load();

    await tester.pumpWidget(_app(state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(
      find.text('The server reported no models. Type the ID above.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, ''), findsWidgets);
  });
}
