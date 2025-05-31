import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/engine.dart';

class SettingsProvider extends ChangeNotifier {
  static const _engineKey = 'engine';
  Engine _engine = Engine.fastai;
  Engine get engine => _engine;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_engineKey);
    if (value != null) {
      _engine = Engine.values.firstWhere(
        (e) => e.name == value,
        orElse: () => Engine.fastai,
      );
    }
    notifyListeners();
  }

  Future<void> setEngine(Engine engine) async {
    _engine = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_engineKey, engine.name);
    notifyListeners();
  }
}
