import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/result_model.dart';
import '../models/engine.dart';
import '../services/api.dart';

/// Notifier that performs the geolocation call and stores the last result.
class GeoProvider extends ChangeNotifier {
  GeoProvider([this._locate = Api.locate]);

  final Future<ResultModel> Function(File, Engine) _locate;

  ResultModel? _result;
  ResultModel? get result => _result;

  /// Upload [file] to the backend; notify listeners when done.
  Future<ResultModel> locate(File file, Engine engine) async {
    final res = await _locate(file, engine);
    _result = res;
    notifyListeners();
    return res;
  }
}
