import 'package:app/providers/locale_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  test('setLocale notifies listeners', () {
    final provider = LocaleProvider();
    var notified = false;
    provider.addListener(() => notified = true);
    provider.setLocale(const Locale('de'));
    expect(provider.locale.languageCode, 'de');
    expect(notified, isTrue);
  });
}
