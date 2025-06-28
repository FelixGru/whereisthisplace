import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:app/main.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/screens/result.dart';
import 'package:app/screens/settings.dart';
import 'package:app/models/engine.dart';
import 'package:app/models/result_model.dart';
import 'package:app/providers/geo_provider.dart';
import 'package:app/providers/locale_provider.dart';
import 'package:app/providers/settings_provider.dart';
import 'package:app/providers/pro_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:app/widgets/map_widget.dart';

void main() {
  testWidgets('Home screen has expected widgets', (WidgetTester tester) async {
    await tester.pumpWidget(const WhereApp());
    await tester.pump();
    expect(find.text('Pick Image'), findsOneWidget);
    expect(find.text('Locate'), findsOneWidget);
    expect(find.text('No image selected'), findsOneWidget);
    expect(find.byKey(const Key('settings_button')), findsOneWidget);
  });

  testWidgets('Navigate from home to result page', (WidgetTester tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => GeoProvider(_fakeLocate)),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => ProProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(key: key),
        ),
      ),
    );
    await tester.pump();

    final dummy = XFile.fromData(Uint8List(0), name: 'dummy.png');
    (key.currentState as dynamic).setImage(dummy);
    await tester.pump();

    await tester.tap(find.text('Locate'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confidence_text')), findsOneWidget);
    expect(find.byKey(const Key('share_button')), findsOneWidget);
    expect(find.byType(MapWidget), findsOneWidget);
  });

}

Future<ResultModel> _fakeLocate(File file, Engine engine) async {
  return ResultModel(latitude: 1, longitude: 2, confidence: 0.5);
}
