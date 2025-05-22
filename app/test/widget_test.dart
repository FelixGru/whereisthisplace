import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:app/main.dart';
import 'package:app/screens/home.dart';
import 'package:app/services/api.dart';
import 'package:app/models/result_model.dart';

import 'package:mapbox_gl/mapbox_gl.dart';

void main() {
  testWidgets('Home screen has expected widgets', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Pick Image'), findsOneWidget);
    expect(find.text('Locate'), findsOneWidget);
    expect(find.text('No image selected'), findsOneWidget);
  });

  testWidgets('Navigate from home to result page', (WidgetTester tester) async {
    final key = GlobalKey();
    final api = _FakeApi();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(key: key, api: api)));

    final dummy = XFile.fromData(Uint8List(0), name: 'dummy.png');
    (key.currentState as dynamic).setImage(dummy);
    await tester.pump();

    await tester.tap(find.text('Locate'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confidence_text')), findsOneWidget);
    expect(find.byKey(const Key('share_button')), findsOneWidget);
    
    expect(find.byType(MapboxMap), findsOneWidget);
 main
  });
}

class _FakeApi extends Api {
  @override
  Future<ResultModel> locate(File file) async {
    return ResultModel(latitude: 1, longitude: 2, confidence: 0.5);
  }
}
