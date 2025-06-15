import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

import 'package:app/models/result_model.dart';
import 'package:app/models/engine.dart';

/* ---------- endpoint selection ---------- */
const _backendHost = String.fromEnvironment('BACKEND_HOST', defaultValue: 'dualstack.bbalancer-1902268736.eu-central-1.elb.amazonaws.com');
const _androidEmulatorHost = '10.0.2.2';

final String _baseUrl = (() {
  // Use emulator host only for actual Android emulator, not real devices
  if (kDebugMode && Platform.isAndroid) {
    // Check if running on emulator vs real device
    // For emulator: use 10.0.2.2:8000
    // For real device: use load balancer on port 80
    return 'http://$_backendHost';
  }
  
  // Production: use load balancer on port 80 (forwards to EC2:8000)
  return 'http://$_backendHost';
})();

/* ---------- API service ---------- */
class Api {
  Api._();

  static Future<ResultModel> locate(File image, Engine engine) async {
    var uri = Uri.parse('$_baseUrl/predict');
    if (engine == Engine.openai) {
      uri = uri.replace(queryParameters: {'mode': 'openai'});
    }
    
    // Debug logging
    print('🚀 API Request URL: $uri');
    print('🚀 Engine mode: ${engine.queryValue}');
    print('🚀 Image path: ${image.path}');
    print('🚀 Image exists: ${await image.exists()}');
    
    final req = http.MultipartRequest('POST', uri);
    
    try {
      // Explicitly set content type to ensure backend accepts it
      final multipartFile = await http.MultipartFile.fromPath(
        'photo', 
        image.path,
        contentType: http_parser.MediaType('image', 'jpeg'),
      );
      print('🚀 MultipartFile created: ${multipartFile.filename}, length: ${multipartFile.length}, contentType: ${multipartFile.contentType}');
      req.files.add(multipartFile);
    } catch (e) {
      print('❌ Error creating MultipartFile: $e');
      throw Exception('Failed to create multipart file: $e');
    }

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    
    // Debug response
    print('🚀 Response status: ${resp.statusCode}');
    print('🚀 Response body: ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('API error ${resp.statusCode}: ${resp.body}');
    }
    
    try {
      final decodedJson = jsonDecode(resp.body);
      print('🚀 Decoded JSON: $decodedJson');
      return ResultModel.fromJson(decodedJson);
    } catch (e) {
      print('❌ JSON parsing error: $e');
      throw Exception('Failed to parse response: $e');
    }
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
