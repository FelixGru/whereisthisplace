import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/providers/geo_provider.dart';
import 'package:app/models/engine.dart';

void main() {
  test('locate stores result and notifies listeners', () async {
    final provider = GeoProvider();
    var notified = false;
    provider.addListener(() => notified = true);
    final result = await provider.locate(File('dummy'), Engine.fastai);
    expect(notified, isTrue);
    expect(result.latitude, 1);
    expect(provider.result, isNotNull);
    expect(provider.result!.latitude, 1);
  });
}

