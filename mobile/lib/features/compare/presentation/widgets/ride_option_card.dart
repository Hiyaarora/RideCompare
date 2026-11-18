import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/pill.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/ride_models.dart';
import 'provider_badge.dart';

/// One row in the comparison list.
class RideOptionCard extends StatelessWidget {
  const RideOptionCard({
    super.key,
    required this.option,
    this.isCheapest = false,
    this.isFastest = false,
    this.extraOverCheapest,
    this.onTap,
  });

  final RideOption option;
  final bool isCheapest;
  final bool isFastest;

  /// How much more this costs than the cheapest visible option (null/0 = don't show).
  final int? extraOverCheapest;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final o = option;
    final highlighted = isCheapest;

    return Pressable(
      onTap: onTap,
      semanticLabel:
          '${o.productName}, ${Fmt.fareRange(o.fare.min, o.fare.max)}, pickup in ${Fmt.minutes(o.pickupEtaMin)}${isCheapest ? ', cheapest' : ''}',
      child: AnimatedContainer(
        duration: Motion.medium,
        padding: const EdgeInsets.all(Gaps.lg),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: highlighted ? AppColors.ink : AppColors.border, width: highlighted ? 1.5 : 1),
          boxShadow: highlighted
              ? const [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 6))]
              : const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'badge-${o.id}',
              child: ProviderBadge(provider: o.provider, category: o.category),
            ),
            const SizedBox(width: Gaps.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCheapest || isFastest || o.hasSurge || !o.available) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (isCheapest) const Pill.success(label: 'Cheapest', icon: Icons.savings_rounded),
                        if (isFastest) const Pill.info(label: 'Fastest', icon: Icons.bolt_rounded),
                        if (!o.available)
                          const Pill.warning(label: 'No drivers nearby', icon: Icons.no_transfer_rounded),
                        if (o.hasSurge)
                          Pill.warning(
                            label: '${o.surgeMultiplier.toStringAsFixed(1)}× demand',
                            icon: Icons.trending_up_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(o.productName, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(o.provider.label, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (o.capacity != null) ...[
                        const Text('  ·  ', style: TextStyle(color: AppColors.inkFaint)),
                        const Icon(Icons.person_rounded, size: 13, color: AppColors.inkMuted),
                        Text(' ${o.capacity}', style: t.bodySmall),
                      ],
                    ],
                  ),
                  const SizedBox(height: Gaps.sm),
                  Wrap(
                    spacing: Gaps.md,
                    runSpacing: 4,
                    children: [
                      _Meta(icon: Icons.schedule_rounded, text: '${Fmt.minutes(o.pickupEtaMin)} away', strong: true),
                      _Meta(icon: Icons.route_rounded, text: '${Fmt.minutes(o.tripDurationMin)} trip'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gaps.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Fmt.fareRange(o.fare.min, o.fare.max, currency: o.fare.currency),
                  style: t.titleLarge?.copyWith(fontSize: 19, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                const SizedBox(height: 4),
                // Always say whether this is a confirmed upfront fare or the provider's estimate range.
                Text(
                  o.isUpfront ? 'upfront fare' : 'live estimate',
                  style: t.bodySmall?.copyWith(color: o.isUpfront ? AppColors.success : AppColors.inkFaint),
                ),
                if (extraOverCheapest != null && extraOverCheapest! > 0)
                  Text('+${Fmt.money(extraOverCheapest!)}', style: t.bodySmall?.copyWith(color: AppColors.inkFaint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.strong = false});
  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: strong ? AppColors.ink : AppColors.inkMuted),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            color: strong ? AppColors.ink : AppColors.inkMuted,
            fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

/// Loading placeholder shaped like a [RideOptionCard].
class RideOptionCardSkeleton extends StatelessWidget {
  const RideOptionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gaps.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          _Sk(w: 52, h: 52, r: 16),
          SizedBox(width: Gaps.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Sk(w: 130, h: 16),
                SizedBox(height: 8),
                _Sk(w: 70, h: 12),
                SizedBox(height: 10),
                _Sk(w: 160, h: 12),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [_Sk(w: 76, h: 20), SizedBox(height: 8), _Sk(w: 48, h: 12)],
          ),
        ],
      ),
    );
  }
}

class _Sk extends StatelessWidget {
  const _Sk({required this.w, required this.h, this.r = 6});
  final double w;
  final double h;
  final double r;
  @override
  Widget build(BuildContext context) => SkeletonBox(width: w, height: h, radius: r);
}
