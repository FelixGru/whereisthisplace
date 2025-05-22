library mapbox_gl;

import 'package:flutter/widgets.dart';

class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

class CameraPosition {
  final LatLng target;
  final double zoom;
  final double bearing;
  final double tilt;
  const CameraPosition({required this.target, this.zoom = 0, this.bearing = 0, this.tilt = 0});

  @override
  int get hashCode => Object.hash(target, zoom, bearing, tilt);
}

class SymbolOptions {
  final LatLng geometry;
  const SymbolOptions({required this.geometry});
}

class MapboxMapController {
  Future<void> addSymbol(SymbolOptions options) async {}
}

class MapboxMap extends StatelessWidget {
  final String accessToken;
  final CameraPosition initialCameraPosition;
  final void Function(MapboxMapController)? onMapCreated;
  const MapboxMap({super.key, required this.accessToken, required this.initialCameraPosition, this.onMapCreated});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onMapCreated?.call(MapboxMapController());
    });
    return Container(color: const Color(0xFFEEEEEE));
  }
}
