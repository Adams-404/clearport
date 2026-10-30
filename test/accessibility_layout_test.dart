import 'package:clearport/theme.dart';
import 'package:clearport/widgets/composer.dart';
import 'package:clearport/widgets/copy_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('composer remains usable at large text scale on a narrow screen', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox()),
                Composer(
                  controller: controller,
                  focusNode: focusNode,
                  isStreaming: false,
                  onSend: () {},
                  onStop: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.bySemanticsLabel('Send message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copy control exposes an accessible button label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: CopyButton(text: 'sample', tooltip: 'Copy message'),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Copy message'), findsOneWidget);
  });
}
