import 'package:material_ui/material_ui.dart';

import '../../../../core/maps/app_maps.dart';
import '../../../../core/theme/tokens.dart';
import '../../../places/domain/place.dart';
import '../../domain/ride_models.dart';

/// Pickup → destination as two connected stops.
class RouteStops extends StatelessWidget {
  const RouteStops({super.key, required this.pickup, required this.drop, this.dense = false});
  final Place pickup;
  final Place drop;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget stop(Place p, {required bool isPickup}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Center(child: StopMarker(isPickup: isPickup)),
        ),
        const SizedBox(width: Gaps.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.label, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (!dense && p.address.isNotEmpty)
                Text(p.address, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );

    return Column(
      children: [
        stop(pickup, isPickup: true),
        Row(
          children: [
            SizedBox(
              width: 20,
              height: dense ? 14 : 20,
              child: Center(child: Container(width: 2, color: AppColors.border)),
            ),
          ],
        ),
        stop(drop, isPickup: false),
      ],
    );
  }
}

class StopMarker extends StatelessWidget {
  const StopMarker({super.key, required this.isPickup});
  final bool isPickup;

  @override
  Widget build(BuildContext context) => isPickup
      ? Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.pickupDot,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFBDEBD0), width: 3, strokeAlign: BorderSide.strokeAlignOutside),
          ),
        )
      : Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(2)),
        );
}

/// Route preview map for a comparison (free OpenStreetMap or Google, per MAP_ENGINE).
class RouteMapPreview extends StatelessWidget {
  const RouteMapPreview({super.key, required this.comparison, this.height = 180});
  final Comparison comparison;
  final double height;

  @override
  Widget build(BuildContext context) => RouteMap(
    pickup: (lat: comparison.pickup.lat, lng: comparison.pickup.lng),
    drop: (lat: comparison.drop.lat, lng: comparison.drop.lng),
    polyline: comparison.route.polyline,
    height: height,
  );
}
