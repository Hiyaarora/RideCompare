import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/ride_models.dart';

/// Shown when no provider returned a real price. RideCompare never shows invented prices.
class LivePricingUnavailable extends StatelessWidget {
  const LivePricingUnavailable({super.key, required this.providers});
  final List<ProviderStatus> providers;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Gaps.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.price_change_outlined, color: AppColors.inkMuted),
              const SizedBox(width: Gaps.sm),
              Expanded(child: Text('Live pricing unavailable', style: t.titleMedium)),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          Text(
            'RideCompare only shows prices returned by an authorised provider API. None returned a price for this trip.',
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// "UPFRONT FARE" (a confirmed fixed price) vs "ESTIMATE" (a provider's low–high range).
class PriceTypeTag extends StatelessWidget {
  const PriceTypeTag({super.key, required this.type});
  final PriceType type;

  @override
  Widget build(BuildContext context) {
    final upfront = type == PriceType.upfront;
    final color = upfront ? AppColors.success : AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: upfront ? AppColors.successSoft : AppColors.infoSoft,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(upfront ? Icons.verified_rounded : Icons.sensors_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            upfront ? 'LIVE · UPFRONT FARE' : 'LIVE · ESTIMATE',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: color),
          ),
        ],
      ),
    );
  }
}
