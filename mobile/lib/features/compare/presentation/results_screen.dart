import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/state_views.dart';
import '../application/comparison_controller.dart';
import '../application/filters_controller.dart';
import '../application/trip_controller.dart';
import '../domain/ride_models.dart';
import 'widgets/price_notice.dart';
import 'widgets/filter_bar.dart';
import 'widgets/provider_badge.dart';
import 'widgets/ride_option_card.dart';
import 'widgets/route_view.dart';

/// The core screen: every ride option for the trip, side by side.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(comparisonProvider);
    final trip = ref.watch(tripProvider);

    // A failed refresh keeps the old prices on screen; tell the user with a snackbar.
    ref.listen(comparisonProvider, (prev, next) {
      if (next.hasError && !next.isLoading && next.hasValue && prev?.isLoading == true) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text("Couldn't refresh prices. ${toFailure(next.error!).title}.")));
      }
    });

    final comparison = async.value;
    final refreshing = async.isLoading && comparison != null;

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.ink,
        edgeOffset: 100,
        onRefresh: () => ref.read(comparisonProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              title: const Text('Compare rides'),
              actions: [
                _RefreshButton(
                  refreshing: refreshing,
                  onPressed: comparison == null && async.isLoading
                      ? null
                      : () => ref.read(comparisonProvider.notifier).refresh(),
                ),
                const SizedBox(width: Gaps.sm),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  child: refreshing ? const LinearProgressIndicator(minHeight: 2) : const SizedBox(height: 2),
                ),
              ),
            ),
            if (trip.pickup != null && trip.drop != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.xs, Gaps.page, Gaps.md),
                  child: _TripSummary(comparison: comparison, trip: trip, loading: async.isLoading),
                ),
              ),
            ..._body(context, ref, async),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, WidgetRef ref, AsyncValue<Comparison> async) {
    final comparison = async.value;

    // First load
    if (comparison == null && async.isLoading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.lg, Gaps.page, Gaps.lg),
          sliver: SliverList.separated(
            itemCount: 6,
            separatorBuilder: (_, _) => const SizedBox(height: Gaps.md),
            itemBuilder: (_, _) => const RideOptionCardSkeleton(),
          ),
        ),
      ];
    }

    // Failed with nothing to show
    if (comparison == null) {
      final failure = toFailure(async.error ?? const UnexpectedFailure());
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: ErrorView(
              error: failure,
              onRetry: () => ref.read(comparisonProvider.notifier).refresh(),
              extraActions: [
                if (!failure.canRetry)
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                    onPressed: () => context.pop(),
                    child: const Text('Change trip'),
                  ),
              ],
            ),
          ),
        ),
      ];
    }

    final filters = ref.watch(filtersProvider);
    final visible = applyFilters(comparison.options, filters);
    final providerStates = {for (final p in comparison.providers) p.provider: p.state};
    final cheapestVisible = visible.isEmpty ? null : visible.reduce((a, b) => b.fare.min < a.fare.min ? b : a);
    final fastestVisible = visible.isEmpty ? null : visible.reduce((a, b) => b.totalMinutes < a.totalMinutes ? b : a);

    return [
      if (comparison.dataMode == DataMode.unavailable)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xs),
            child: LivePricingUnavailable(providers: comparison.providers),
          ),
        )
      else
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedHeader(
            height: 116,
            child: FilterBar(options: comparison.options, providerStates: providerStates),
          ),
        ),
      if (comparison.dataMode == DataMode.unavailable)
        const SliverToBoxAdapter(child: SizedBox.shrink())
      else if (visible.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: _EmptyResults(hasAnyOptions: comparison.options.isNotEmpty)),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.xs, Gaps.page, Gaps.lg),
          sliver: SliverList.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: Gaps.md),
            itemBuilder: (context, i) {
              final o = visible[i];
              return FadeSlideIn(
                // Re-animate when the data or filters change.
                key: ValueKey('${comparison.generatedAt.millisecondsSinceEpoch}-${filters.hashCode}-${o.id}'),
                index: i,
                child: RideOptionCard(
                  option: o,
                  isCheapest: o.id == cheapestVisible?.id,
                  isFastest: o.id == fastestVisible?.id && visible.length > 1,
                  extraOverCheapest: cheapestVisible == null ? null : o.fare.min - cheapestVisible.fare.min,
                  onTap: () => context.push('/results/option/${Uri.encodeComponent(o.id)}'),
                ),
              );
            },
          ),
        ),
      SliverToBoxAdapter(child: _ProviderNotes(providers: comparison.providers)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.xxxl + Gaps.lg),
          child: Text(
            'Checked ${Fmt.time(comparison.generatedAt)} · Pull down to refresh.\n'
            'Only prices returned by official provider APIs are shown. RideCompare does not book rides.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkFaint, height: 1.5),
          ),
        ),
      ),
    ];
  }
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.comparison, required this.trip, required this.loading});
  final Comparison? comparison;
  final TripState trip;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final route = comparison?.route;
    return Container(
      padding: const EdgeInsets.all(Gaps.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(
        children: [
          RouteStops(pickup: trip.pickup!, drop: trip.drop!, dense: true),
          const SizedBox(height: Gaps.md),
          AnimatedSwitcher(
            duration: Motion.medium,
            child: route == null && !loading
                ? const SizedBox.shrink(key: ValueKey('none'))
                : route == null
                ? const Row(
                    key: ValueKey('sk'),
                    children: [
                      SkeletonBox(width: 70, height: 26, radius: Radii.pill),
                      SizedBox(width: 8),
                      SkeletonBox(width: 70, height: 26, radius: Radii.pill),
                    ],
                  )
                : Wrap(
                    key: const ValueKey('stats'),
                    spacing: Gaps.sm,
                    runSpacing: Gaps.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Stat(icon: Icons.straighten_rounded, text: Fmt.km(route.distanceKm)),
                      _Stat(icon: Icons.schedule_rounded, text: '~${Fmt.minutes(route.durationMin)} drive'),
                      if (route.isEstimated)
                        Tooltip(
                          message: 'Distance and time are estimated from straight-line distance.',
                          child: Text(
                            'est. route',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(Radii.pill)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
        ),
      ],
    ),
  );
}

class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.refreshing, required this.onPressed});
  final bool refreshing;
  final VoidCallback? onPressed;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void didUpdateWidget(covariant _RefreshButton old) {
    super.didUpdateWidget(old);
    if (widget.refreshing && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.refreshing && _c.isAnimating) {
      _c.forward(from: _c.value).then((_) => _c.reset());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Refresh prices',
    onPressed: widget.refreshing ? null : widget.onPressed,
    style: IconButton.styleFrom(backgroundColor: AppColors.surface),
    icon: RotationTransition(turns: _c, child: const Icon(Icons.refresh_rounded)),
  );
}

class _EmptyResults extends ConsumerWidget {
  const _EmptyResults({required this.hasAnyOptions});
  final bool hasAnyOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasAnyOptions) {
      return const MessageView(
        icon: Icons.no_transfer_rounded,
        title: 'No rides available',
        message:
            'None of the providers have rides for this trip right now. Try refreshing in a minute or change your trip.',
      );
    }
    final f = ref.watch(filtersProvider);
    return MessageView(
      icon: Icons.filter_alt_off_rounded,
      title: f.providers.isEmpty ? 'No providers selected' : 'No rides match your filters',
      message: f.providers.isEmpty
          ? 'Turn on at least one of Uber, Ola or Rapido to see prices.'
          : 'Try a different ride type or include more providers.',
      actions: [
        OutlinedButton(onPressed: () => ref.read(filtersProvider.notifier).reset(), child: const Text('Reset filters')),
      ],
    );
  }
}

/// Explains providers that failed or have no rides, instead of silently hiding them.
class _ProviderNotes extends StatelessWidget {
  const _ProviderNotes({required this.providers});
  final List<ProviderStatus> providers;

  @override
  Widget build(BuildContext context) {
    final notes = providers.where((p) => p.state != ProviderState.ok).toList();
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, 0),
      child: Column(
        children: [
          for (final p in notes)
            Container(
              margin: const EdgeInsets.only(bottom: Gaps.sm),
              padding: const EdgeInsets.all(Gaps.md),
              decoration: BoxDecoration(
                color: p.state == ProviderState.error ? AppColors.dangerSoft : AppColors.surface,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                children: [
                  ProviderDot(provider: p.provider),
                  const SizedBox(width: Gaps.sm),
                  Expanded(
                    child: Text(
                      [
                        '${p.provider.label}: ${p.message ?? 'Live pricing unavailable'}',
                        if (p.reason != null && p.reason!.isNotEmpty) p.reason!,
                      ].join('\n'),
                      style: TextStyle(
                        fontSize: 13,
                        color: p.state == ProviderState.error ? AppColors.danger : AppColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PinnedHeader extends SliverPersistentHeaderDelegate {
  _PinnedHeader({required this.child, required this.height});
  final Widget child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.background,
      boxShadow: overlapsContent || shrinkOffset > 0
          ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4))]
          : null,
    ),
    child: SizedBox(height: height, child: child),
  );

  @override
  bool shouldRebuild(covariant _PinnedHeader old) => old.child != child || old.height != height;
}
