import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import 'package:app/models/result_model.dart';   // ← use the existing model
import 'package:app/models/engine.dart';

/* ---------- endpoint selection ---------- */
const _prodHost = '52.28.72.57';
const _androidEmulatorHost = '10.0.2.2';
const _overrideHost = String.fromEnvironment('BACKEND_HOST');

final String _baseUrl = (() {
  if (_overrideHost.isNotEmpty) return 'http://$_overrideHost:8000';
  if (!kDebugMode) return 'http://$_prodHost:8000';
  // Default to public IP on mobile; use emulator host only if overridden
  if (Platform.isAndroid || Platform.isIOS) {
    return 'http://$_prodHost:8000';
  }
  return 'http://$_androidEmulatorHost:8000';
})();

/* ---------- API service ---------- */
class Api {
  Api._();

  static Future<ResultModel> locate(File image, Engine engine) async {
    final query = engine == Engine.openai ? '?mode=openai' : '';
    final uri = Uri.parse('$_baseUrl/predict$query');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('photo', image.path));

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception('API error ${resp.statusCode}: ${resp.body}');
    }
    return ResultModel.fromJson(jsonDecode(resp.body));
  }

  static Future<bool> isHealthy() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/health'));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
