import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/result_model.dart';

/// Displays the prediction result using a static Mapbox map image.
class ResultScreen extends StatelessWidget {
  final ResultModel result;
  const ResultScreen({super.key, required this.result});

  /// Builds the Mapbox static map URL with a pin at the predicted coordinates.
  String get _mapUrl {
    const token = 'YOUR_MAPBOX_ACCESS_TOKEN';
    final lat = result.latitude;
    final lon = result.longitude;
    return 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/static/'
        'pin-s+ff0000($lon,$lat)/$lon,$lat,12/600x400?access_token=$token';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      'https://maps.google.com/?q=${result.latitude},${result.longitude}',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Image.network(_mapUrl, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Confidence: ${(result.confidence * 100).toStringAsFixed(2)}%',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}
