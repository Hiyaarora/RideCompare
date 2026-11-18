import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/maps/app_maps.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../compare/application/trip_controller.dart';
import '../application/places_providers.dart';
import '../domain/place.dart';

/// Pick a location by moving the map under a fixed centre pin. Pops with the chosen [Place].
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({super.key, required this.field, this.initial});
  final TripField field;
  final Place? initial;

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  final _map = PickerMapController();
  late MapPoint _center = _startPoint();
  Place? _resolved;
  bool _moving = false;
  bool _resolving = false;
  Timer? _debounce;
  int _requestSeq = 0;

  /// Start at the field's current value, else the other end of the trip, else a default.
  MapPoint _startPoint() {
    final trip = ref.read(tripProvider);
    final p = widget.initial ?? (widget.field == TripField.pickup ? trip.drop : trip.pickup);
    return p != null ? (lat: p.lat, lng: p.lng) : (lat: AppConfig.fallbackLat, lng: AppConfig.fallbackLng);
  }

  @override
  void initState() {
    super.initState();
    _resolve();
    if (widget.initial == null) _goToMyLocation(silent: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _resolve() async {
    final seq = ++_requestSeq;
    setState(() => _resolving = true);
    try {
      final p = await ref.read(placesRepositoryProvider).reverseGeocode(_center.lat, _center.lng);
      if (mounted && seq == _requestSeq) setState(() => _resolved = p);
    } catch (_) {
      if (mounted && seq == _requestSeq) {
        setState(() => _resolved = Place(name: 'Pinned location', lat: _center.lat, lng: _center.lng));
      }
    } finally {
      if (mounted && seq == _requestSeq) setState(() => _resolving = false);
    }
  }

  Future<void> _goToMyLocation({bool silent = false}) async {
    final svc = ref.read(locationServiceProvider);
    if (silent && !await svc.hasPermission()) return;
    try {
      final pos = await svc.currentPosition();
      _map.moveTo((lat: pos.lat, lng: pos.lng));
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toFailure(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink),
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
      ),
      body: Stack(
        children: [
          PickerMap(
            initialCenter: _center,
            controller: _map,
            onMoveStart: () => setState(() => _moving = true),
            onMove: (p) => _center = p,
            onIdle: () {
              if (!mounted) return;
              setState(() => _moving = false);
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), _resolve);
            },
          ),
          // Hint
          Positioned(
            top: MediaQuery.paddingOf(context).top + 64,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _moving ? 0 : 1,
                  duration: Motion.fast,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(Radii.pill)),
                    child: const Text(
                      'Drag the map to move the pin',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Centre pin: lifts while the map moves.
          IgnorePointer(
            child: Center(
              child: AnimatedSlide(
                duration: Motion.fast,
                offset: Offset(0, _moving ? -0.75 : -0.5),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 48,
                  color: widget.field == TripField.pickup ? AppColors.pickupDot : AppColors.ink,
                  shadows: const [Shadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
                ),
              ),
            ),
          ),
          Positioned(
            right: Gaps.lg,
            bottom: 210,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              tooltip: 'My location',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                Gaps.page,
                Gaps.xl,
                Gaps.page,
                Gaps.lg + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
                boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.field == TripField.pickup ? 'Pickup point' : 'Destination', style: t.bodySmall),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: Motion.fast,
                    child: (_resolving || _moving || _resolved == null)
                        ? const Column(
                            key: ValueKey('loading'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 200, height: 20),
                              SizedBox(height: 6),
                              SkeletonBox(width: 260, height: 13),
                            ],
                          )
                        : Column(
                            key: ValueKey(_resolved),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_resolved!.name, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                _resolved!.address,
                                style: t.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: Gaps.lg),
                  FilledButton(
                    onPressed: (_resolving || _moving || _resolved == null)
                        ? null
                        : () => context.pop(
                            Place(
                              name: _resolved!.name,
                              address: _resolved!.address,
                              placeId: _resolved!.placeId,
                              lat: _center.lat,
                              lng: _center.lng,
                            ),
                          ),
                    child: Text('Confirm ${widget.field == TripField.pickup ? 'pickup' : 'destination'}'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
