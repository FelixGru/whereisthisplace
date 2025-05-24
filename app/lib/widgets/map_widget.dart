import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

class MapWidget extends StatefulWidget {
  final double latitude;
  final double longitude;

  const MapWidget({
    Key? key,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  mapbox.MapboxMap? mapboxMap;

  _onMapCreated(mapbox.MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    
    // Add a marker at the location
    mapboxMap.annotations.createPointAnnotationManager().then((pointAnnotationManager) async {
      final options = <mapbox.PointAnnotationOptions>[
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(
              widget.longitude,
              widget.latitude,
            ),
          ),
        ),
      ];
      await pointAnnotationManager.createMulti(options);
    });
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Replace with your PUBLIC Mapbox token (starts with pk.)
    const String ACCESS_TOKEN = 'YOUR_PUBLIC_MAPBOX_TOKEN_HERE';
    
    // Set the access token
    mapbox.MapboxOptions.setAccessToken(ACCESS_TOKEN);
    
    return mapbox.MapWidget(
      key: const ValueKey("mapWidget"),
      resourceOptions: mapbox.ResourceOptions(accessToken: ACCESS_TOKEN),
      cameraOptions: mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(
            widget.longitude,
            widget.latitude,
          ),
        ),
        zoom: 14.0,
      ),
      styleUri: mapbox.MapboxStyles.SATELLITE_STREETS,
      onMapCreated: _onMapCreated,
    );
  }
}
