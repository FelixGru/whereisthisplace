import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/result_model.dart';

class ResultScreen extends StatelessWidget {
  final ResultModel result;

  const ResultScreen({super.key, required this.result});

  void _shareLocation() {
    final url = 'https://www.google.com/maps/search/?api=1&query=${result.latitude},${result.longitude}';
    Share.share('Check out this location: '+url);
  }

  @override
  Widget build(BuildContext context) {
    final mapUrl = 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/static/pin-s(${result.longitude},${result.latitude})/${result.longitude},${result.latitude},14/600x400?access_token=MAPBOX_ACCESS_TOKEN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          Image.network(
            mapUrl,
            height: 300,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          const SizedBox(height: 16),
          Text('Confidence: ${(result.confidence * 100).toStringAsFixed(2)}%'),
        ],
      ),
    );
  }
}
