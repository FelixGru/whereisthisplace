import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/result_model.dart';

/// Displays the location result on a Mapbox map with a share button.
class ResultScreen extends StatelessWidget {
  final ResultModel result;
  const ResultScreen({super.key, required this.result});

  void _share() {
    final text =
        'Location: \${result.latitude}, \${result.longitude} (confidence \${(result.confidence * 100).toStringAsFixed(1)}%)';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        actions: [
          IconButton(
            key: const Key('share_button'),
            onPressed: _share,
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MapboxMap(
              accessToken: 'YOUR_MAPBOX_ACCESS_TOKEN',
              initialCameraPosition: CameraPosition(
                target: LatLng(result.latitude, result.longitude),
                zoom: 12,
              ),
              onMapCreated: (controller) {
                controller.addSymbol(
                  SymbolOptions(
                    geometry: LatLng(result.latitude, result.longitude),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Confidence: \${(result.confidence * 100).toStringAsFixed(1)}%',
              key: const Key('confidence_text'),
            ),
          ),
        ],
      ),
    );
  }
}

