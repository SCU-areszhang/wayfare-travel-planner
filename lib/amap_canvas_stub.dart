import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class AmapCanvasMarker {
  const AmapCanvasMarker({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.point,
    required this.color,
  });

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final LatLng point;
  final Color color;
}

class AmapPickResult {
  const AmapPickResult({
    required this.point,
    required this.name,
    this.address,
  });

  final LatLng point;
  final String name;
  final String? address;
}

class AmapRouteSegment {
  const AmapRouteSegment({
    required this.points,
    required this.color,
  });

  final List<LatLng> points;
  final Color color;
}

class AmapCanvas extends StatelessWidget {
  const AmapCanvas({
    required this.jsKey,
    required this.securityCode,
    required this.markers,
    required this.routeSegments,
    required this.selectedPoint,
    required this.pickMode,
    required this.interactive,
    required this.primaryColor,
    required this.onMarkerTapped,
    required this.onPointPicked,
    this.visible = true,
    super.key,
  });

  final String jsKey;
  final String securityCode;
  final List<AmapCanvasMarker> markers;
  final List<AmapRouteSegment> routeSegments;
  final LatLng? selectedPoint;
  final bool pickMode;
  final bool interactive;
  final Color primaryColor;
  final ValueChanged<String> onMarkerTapped;
  final ValueChanged<AmapPickResult> onPointPicked;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}
