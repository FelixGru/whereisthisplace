import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import 'package:app/models/result_model.dart';   // ← use the existing model

/* ---------- endpoint selection ---------- */
const _prodHost = '18.184.4.124';
const _androidEmulatorHost = '10.0.2.2';

final String _baseUrl = (() {
  if (!kDebugMode) return 'http://$_prodHost:8000';
  return Platform.isAndroid ? 'http://$_androidEmulatorHost:8000'
                            : 'http://$_prodHost:8000';
})();

/* ---------- API service ---------- */
class Api {
  Api._();

  static Future<ResultModel> locate(File image) async {
    final uri = Uri.parse('$_baseUrl/predict');
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

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
