import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/providers/settings_provider.dart';
import 'package:app/models/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to fastai when no value stored', () async {
    final provider = SettingsProvider();
    await Future.delayed(Duration.zero);
    expect(provider.engine, Engine.fastai);
  });

  test('setEngine persists value', () async {
    var provider = SettingsProvider();
    await Future.delayed(Duration.zero);
    await provider.setEngine(Engine.openai);

    provider = SettingsProvider();
    await Future.delayed(Duration.zero);
    expect(provider.engine, Engine.openai);
  });
}
