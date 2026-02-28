import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_chatgpt/widgets/user_message.dart';
import 'package:flutter_chatgpt/widgets/loading.dart';

void main() {
  testWidgets('User message is displayed', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserMessage(text: 'Hello'),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('Loading widget is displayed', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Loading(text: 'thinking...'),
      ),
    );
    expect(find.text('thinking...'), findsOneWidget);
  });
}
