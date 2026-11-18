import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/state_views.dart';
import '../application/comparison_controller.dart';
import 'widgets/price_notice.dart';
import 'widgets/provider_badge.dart';
import 'widgets/route_view.dart';

class RideDetailsScreen extends ConsumerWidget {
  const RideDetailsScreen({super.key, required this.optionId});
  final String optionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparison = ref.watch(comparisonProvider).value;
    final option = comparison?.optionById(optionId);

    if (comparison == null || option == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: MessageView(
            icon: Icons.search_off_rounded,
            title: 'Ride no longer available',
            message: 'Prices were refreshed and this option is not in the latest results.',
            actions: [FilledButton(onPressed: () => context.pop(), child: const Text('Back to results'))],
          ),
        ),
      );
    }

    final t = Theme.of(context).textTheme;
    final sameCategory = comparison.options.where((o) => o.category == option.category).toList()
      ..sort((a, b) => a.fare.min.compareTo(b.fare.min));
    final cheapestInCategory = sameCategory.first;
    final rank = sameCategory.indexWhere((o) => o.id == option.id) + 1;

    final sections = <Widget>[
      // Header
      Row(
        children: [
          Hero(
            tag: 'badge-${option.id}',
            child: ProviderBadge(provider: option.provider, category: option.category, size: 64),
          ),
          const SizedBox(width: Gaps.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.productName, style: t.headlineSmall),
                const SizedBox(height: 2),
                Text('${option.provider.label} · ${option.category.label}', style: t.bodyMedium),
              ],
            ),
          ),
        ],
      ),
      if (option.description.isNotEmpty) Text(option.description, style: t.bodyMedium),

      // Price
      Container(
        padding: const EdgeInsets.all(Gaps.xl),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(option.isUpfront ? 'Upfront fare' : 'Estimated fare', style: t.bodyMedium),
                const Spacer(),
                PriceTypeTag(type: option.priceType),
              ],
            ),
            const SizedBox(height: Gaps.sm),
            Text(
              Fmt.fareRange(option.fare.min, option.fare.max, currency: option.fare.currency),
              style: t.headlineMedium?.copyWith(fontSize: 36, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 4),
            Text(
              option.isUpfront
                  ? 'Fixed price quoted by ${option.provider.label} at ${Fmt.time(option.fetchedAt)}.'
                  : 'Range estimated by ${option.provider.label} at ${Fmt.time(option.fetchedAt)}. The final fare may differ.',
              style: t.bodySmall,
            ),
            const SizedBox(height: Gaps.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (option.id == cheapestInCategory.id)
                  Pill.success(label: 'Cheapest ${option.category.label.toLowerCase()}', icon: Icons.savings_rounded)
                else
                  Pill(
                    label:
                        '+${Fmt.money(option.fare.min - cheapestInCategory.fare.min)} vs ${cheapestInCategory.productName}',
                  ),
                if (sameCategory.length > 1) Pill(label: '#$rank of ${sameCategory.length} by price'),
                if (option.hasSurge)
                  Pill.warning(
                    label: '${option.surgeMultiplier.toStringAsFixed(1)}× high demand',
                    icon: Icons.trending_up_rounded,
                  ),
              ],
            ),
          ],
        ),
      ),

      // Key stats
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Gaps.md,
        crossAxisSpacing: Gaps.md,
        childAspectRatio: 2.1,
        children: [
          _StatTile(icon: Icons.hail_rounded, label: 'Pickup in', value: Fmt.minutes(option.pickupEtaMin)),
          _StatTile(icon: Icons.schedule_rounded, label: 'Trip time', value: Fmt.minutes(option.tripDurationMin)),
          _StatTile(
            icon: Icons.straighten_rounded,
            label: 'Distance',
            value: Fmt.km(option.distanceKm ?? comparison.route.distanceKm),
          ),
          _StatTile(icon: Icons.flag_rounded, label: 'Arrive in about', value: Fmt.minutes(option.totalMinutes)),
        ],
      ),

      // Route
      _Section(
        title: 'Route',
        child: Column(
          children: [
            RouteMapPreview(comparison: comparison),
            const SizedBox(height: Gaps.lg),
            RouteStops(pickup: comparison.pickup, drop: comparison.drop),
          ],
        ),
      ),

      // Alternatives
      if (sameCategory.length > 1)
        _Section(
          title: 'Other ${option.category.label.toLowerCase()} options',
          child: Column(
            children: [
              for (final o in sameCategory.where((o) => o.id != option.id))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ProviderBadge(provider: o.provider, category: o.category, size: 40),
                  title: Text(o.productName, style: t.titleSmall),
                  subtitle: Text('${Fmt.minutes(o.pickupEtaMin)} away', style: t.bodySmall),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Fmt.fareRange(o.fare.min, o.fare.max), style: t.titleSmall),
                      _Diff(diff: o.fare.min - option.fare.min),
                    ],
                  ),
                  onTap: () => context.pushReplacement('/results/option/${Uri.encodeComponent(o.id)}'),
                ),
            ],
          ),
        ),

      Container(
        padding: const EdgeInsets.all(Gaps.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkMuted),
            const SizedBox(width: Gaps.sm),
            Expanded(
              child: Text(
                'RideCompare only compares prices. To book this ride, open the ${option.provider.label} app yourself. '
                'Final fares are set by ${option.provider.label} and can change with demand, tolls and waiting time.',
                style: t.bodySmall?.copyWith(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ride details')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.xxxl),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: Gaps.xl),
        itemBuilder: (_, i) => FadeSlideIn(index: i, child: sections[i]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: Gaps.md),
      child,
    ],
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Gaps.md + 2, vertical: Gaps.md),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: Gaps.sm + 2),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted), maxLines: 1),
              Text(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700), maxLines: 1),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Diff extends StatelessWidget {
  const _Diff({required this.diff});
  final int diff;

  @override
  Widget build(BuildContext context) {
    if (diff == 0) return const Text('same price', style: TextStyle(fontSize: 11.5, color: AppColors.inkFaint));
    final cheaper = diff < 0;
    return Text(
      '${cheaper ? '−' : '+'}${Fmt.money(diff.abs())}',
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: cheaper ? AppColors.success : AppColors.inkFaint,
      ),
    );
  }
}
