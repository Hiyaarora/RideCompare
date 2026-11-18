import 'dart:async';

import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:material_ui/material_ui.dart';

import '../config/app_config.dart';
import '../theme/tokens.dart';

/// Map-engine–agnostic map widgets. Screens use these and never import a map SDK directly,
/// so switching between free OpenStreetMap and Google Maps is one build setting (MAP_ENGINE).

typedef MapPoint = ({double lat, double lng});

/// Lets a screen move the picker map (e.g. "my location" button).
class PickerMapController {
  void Function(MapPoint target, double zoom)? _moveTo;

  void moveTo(MapPoint target, {double zoom = 16}) => _moveTo?.call(target, zoom);
}

/// Full-screen map the user drags under a fixed centre pin.
class PickerMap extends StatelessWidget {
  const PickerMap({
    super.key,
    required this.initialCenter,
    required this.controller,
    required this.onMoveStart,
    required this.onMove,
    required this.onIdle,
  });

  final MapPoint initialCenter;
  final PickerMapController controller;
  final VoidCallback onMoveStart;
  final ValueChanged<MapPoint> onMove;
  final VoidCallback onIdle;

  @override
  Widget build(BuildContext context) => switch (AppConfig.mapEngine) {
    MapEngine.osm => _OsmPickerMap(this),
    MapEngine.google => _GooglePickerMap(this),
  };
}

/// Small, non-interactive map showing a route between two stops.
class RouteMap extends StatelessWidget {
  const RouteMap({super.key, required this.pickup, required this.drop, required this.polyline, this.height = 180});

  final MapPoint pickup;
  final MapPoint drop;
  final List<MapPoint> polyline;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Radii.lg),
    child: SizedBox(
      height: height,
      child: switch (AppConfig.mapEngine) {
        MapEngine.osm => _OsmRouteMap(this),
        MapEngine.google => _GoogleRouteMap(this),
      },
    ),
  );
}

// ───────────────────────────── OpenStreetMap (free) ─────────────────────────────

fm.TileLayer _osmTiles() => fm.TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: AppConfig.osmUserAgentPackage,
  maxNativeZoom: 19,
);

// OSM's tile policy requires visible attribution: a small label in the corner.
Widget _osmAttribution() => const Align(
  alignment: Alignment.bottomLeft,
  child: Padding(
    padding: EdgeInsets.all(4),
    child: DecoratedBox(
      decoration: BoxDecoration(color: Color(0xD9FFFFFF), borderRadius: BorderRadius.all(Radius.circular(4))),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text('© OpenStreetMap', style: TextStyle(fontSize: 9.5, color: AppColors.inkMuted)),
      ),
    ),
  ),
);

ll.LatLng _ll(MapPoint p) => ll.LatLng(p.lat, p.lng);

class _OsmPickerMap extends StatefulWidget {
  const _OsmPickerMap(this.config);
  final PickerMap config;

  @override
  State<_OsmPickerMap> createState() => _OsmPickerMapState();
}

class _OsmPickerMapState extends State<_OsmPickerMap> {
  final _map = fm.MapController();
  Timer? _idle;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    widget.config.controller._moveTo = (t, z) => _map.move(_ll(t), z);
  }

  @override
  void dispose() {
    _idle?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _onPosition(fm.MapCamera camera, bool _) {
    if (!_moving) {
      _moving = true;
      widget.config.onMoveStart();
    }
    widget.config.onMove((lat: camera.center.latitude, lng: camera.center.longitude));
    // flutter_map has no "camera idle" event; treat a short pause in movement as idle.
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 350), () {
      _moving = false;
      widget.config.onIdle();
    });
  }

  @override
  Widget build(BuildContext context) => fm.FlutterMap(
    mapController: _map,
    options: fm.MapOptions(
      initialCenter: _ll(widget.config.initialCenter),
      initialZoom: 16,
      minZoom: 4,
      maxZoom: 19,
      interactionOptions: const fm.InteractionOptions(flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate),
      onPositionChanged: _onPosition,
    ),
    children: [_osmTiles(), _osmAttribution()],
  );
}

class _OsmRouteMap extends StatelessWidget {
  const _OsmRouteMap(this.c);
  final RouteMap c;

  @override
  Widget build(BuildContext context) {
    final pts = c.polyline.isEmpty ? [_ll(c.pickup), _ll(c.drop)] : c.polyline.map(_ll).toList();
    return fm.FlutterMap(
      options: fm.MapOptions(
        initialCameraFit: fm.CameraFit.coordinates(
          coordinates: [...pts, _ll(c.pickup), _ll(c.drop)],
          padding: const EdgeInsets.all(36),
        ),
        interactionOptions: const fm.InteractionOptions(flags: fm.InteractiveFlag.none),
      ),
      children: [
        _osmTiles(),
        fm.PolylineLayer(
          polylines: [
            fm.Polyline(points: pts, strokeWidth: 6, color: Colors.white),
            fm.Polyline(points: pts, strokeWidth: 4, color: AppColors.ink),
          ],
        ),
        fm.MarkerLayer(
          markers: [
            fm.Marker(
              point: _ll(c.pickup),
              width: 22,
              height: 22,
              child: const _Dot(color: AppColors.pickupDot, round: true),
            ),
            fm.Marker(
              point: _ll(c.drop),
              width: 20,
              height: 20,
              child: const _Dot(color: AppColors.ink, round: false),
            ),
          ],
        ),
        _osmAttribution(),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.round});
  final Color color;
  final bool round;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: round ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: round ? null : BorderRadius.circular(4),
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
    ),
  );
}

// ───────────────────────────── Google Maps ─────────────────────────────

gm.LatLng _g(MapPoint p) => gm.LatLng(p.lat, p.lng);

class _GooglePickerMap extends StatefulWidget {
  const _GooglePickerMap(this.config);
  final PickerMap config;

  @override
  State<_GooglePickerMap> createState() => _GooglePickerMapState();
}

class _GooglePickerMapState extends State<_GooglePickerMap> {
  gm.GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    widget.config.controller._moveTo = (t, z) => _map?.animateCamera(gm.CameraUpdate.newLatLngZoom(_g(t), z));
  }

  @override
  Widget build(BuildContext context) => gm.GoogleMap(
    initialCameraPosition: gm.CameraPosition(target: _g(widget.config.initialCenter), zoom: 16),
    onMapCreated: (c) => _map = c,
    myLocationEnabled: false,
    myLocationButtonEnabled: false,
    zoomControlsEnabled: false,
    mapToolbarEnabled: false,
    compassEnabled: false,
    onCameraMoveStarted: widget.config.onMoveStart,
    onCameraMove: (p) => widget.config.onMove((lat: p.target.latitude, lng: p.target.longitude)),
    onCameraIdle: widget.config.onIdle,
  );
}

class _GoogleRouteMap extends StatelessWidget {
  const _GoogleRouteMap(this.c);
  final RouteMap c;

  @override
  Widget build(BuildContext context) {
    final pts = c.polyline.isEmpty ? [_g(c.pickup), _g(c.drop)] : c.polyline.map(_g).toList();
    final lats = [c.pickup.lat, c.drop.lat];
    final lngs = [c.pickup.lng, c.drop.lng];
    final bounds = gm.LatLngBounds(
      southwest: gm.LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
      northeast: gm.LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
    );
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: _g(c.pickup), zoom: 12),
      liteModeEnabled: Theme.of(context).platform == TargetPlatform.android,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      markers: {
        gm.Marker(
          markerId: const gm.MarkerId('pickup'),
          position: _g(c.pickup),
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueGreen),
        ),
        gm.Marker(markerId: const gm.MarkerId('drop'), position: _g(c.drop)),
      },
      polylines: {gm.Polyline(polylineId: const gm.PolylineId('route'), points: pts, width: 4, color: AppColors.ink)},
      onMapCreated: (m) => Future.delayed(
        const Duration(milliseconds: 250),
        () => m.moveCamera(gm.CameraUpdate.newLatLngBounds(bounds, 40)).catchError((_) {}),
      ),
    );
  }
}
