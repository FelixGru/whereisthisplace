import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:app/main.dart';
import 'package:app/models/result_model.dart';
import 'package:app/screens/home.dart';
import 'package:app/screens/result.dart';
import 'package:app/services/api.dart';

void main() {
  testWidgets('Home screen has expected widgets', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Pick Image'), findsOneWidget);
    expect(find.text('Locate'), findsOneWidget);
    expect(find.text('No image selected'), findsOneWidget);
  });

  testWidgets('Navigate to result screen on locate', (WidgetTester tester) async {
    final fakeApi = _FakeApi();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(api: fakeApi)));

    final state = tester.state(find.byType(HomeScreen)) as dynamic;
    state.setImageForTest(XFile('dummy.jpg'));
    await tester.pump();

    await tester.tap(find.text('Locate'));
    await tester.pumpAndSettle();

    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Confidence: 75.00%'), findsOneWidget);
  });

  testWidgets('Result screen shows map and share icon', (WidgetTester tester) async {
    final result = ResultModel(latitude: 1, longitude: 2, confidence: 0.5);
    await tester.pumpWidget(MaterialApp(home: ResultScreen(result: result)));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
    expect(find.text('Confidence: 50.00%'), findsOneWidget);
  });
}

class _FakeApi extends Api {
  @override
  Future<ResultModel> locate(File file) async {
    return ResultModel(latitude: 10, longitude: 20, confidence: 0.75);
  }
}
