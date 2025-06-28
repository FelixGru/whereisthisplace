import 'package:flutter/material.dart';
import '../widgets/map_widget.dart';
import 'package:share_plus/share_plus.dart';

import '../models/result_model.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Displays the location result on a Mapbox map with a share button.
class ResultScreen extends StatelessWidget {
  final ResultModel result;
  const ResultScreen({super.key, required this.result});

  void _share() {
    final text =
        'Location: ${result.latitude}, ${result.longitude} (confidence ${(result.confidence * 100).toStringAsFixed(1)}%)';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    // Debug print to check coordinates
    print('ResultScreen - Latitude: ${result.latitude}, Longitude: ${result.longitude}');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.result),
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
            child: MapWidget(
              latitude: result.latitude,
              longitude: result.longitude,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                  key: const Key('confidence_text'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Coordinates: ${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}