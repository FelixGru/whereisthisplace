import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/screens/home.dart';
import 'package:app/screens/result.dart';

void main() {
  testWidgets('Home screen has expected widgets', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Pick Image'), findsOneWidget);
    expect(find.text('Locate'), findsOneWidget);
    expect(find.text('No image selected'), findsOneWidget);
  });

  testWidgets('Navigate from home to result page', (WidgetTester tester) async {
    final widget = MaterialApp(
      home: HomeScreen(initialImage: XFile('dummy.png')),
    );

    await tester.pumpWidget(widget);

    await tester.tap(find.text('Locate'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(ResultScreen), findsOneWidget);
  });
}
