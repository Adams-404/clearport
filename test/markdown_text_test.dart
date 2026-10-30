import 'package:clearport/theme.dart';
import 'package:clearport/widgets/markdown_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness(String source) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: SingleChildScrollView(child: MarkdownText(source)),
    ),
  );

  testWidgets('renders headings, lists, blockquotes and links', (tester) async {
    await tester.pumpWidget(
      harness('''# Heading

- first item
- second item

> quoted text

[OpenAI](https://openai.com)'''),
    );

    expect(find.text('Heading'), findsOneWidget);
    expect(find.text('first item'), findsOneWidget);
    expect(find.text('second item'), findsOneWidget);
    expect(find.text('quoted text'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
  });

  testWidgets('renders GitHub-flavoured Markdown tables', (tester) async {
    await tester.pumpWidget(
      harness('''| Model | Size |
| --- | ---: |
| Qwen | 1.5B |
| Gemma | 2B |'''),
    );

    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Size'), findsOneWidget);
    expect(find.text('Qwen'), findsOneWidget);
    expect(find.text('1.5B'), findsOneWidget);
    expect(find.text('Gemma'), findsOneWidget);
    expect(find.text('2B'), findsOneWidget);
  });

  testWidgets('keeps fenced code labelled, selectable and copyable', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness('''Example:

\u0060\u0060\u0060dart
void main() {}
\u0060\u0060\u0060'''),
    );

    expect(find.text('dart'), findsOneWidget);
    expect(find.text('void main() {}'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });

  testWidgets('renders an unfinished code fence while streaming', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness('''\u0060\u0060\u0060python
print("still streaming")'''),
    );

    expect(find.text('python'), findsOneWidget);
    expect(find.text('print("still streaming")'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });
}
