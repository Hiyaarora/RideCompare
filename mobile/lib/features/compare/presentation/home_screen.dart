import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/pressable.dart';
import '../../places/domain/place.dart';
import '../application/comparison_controller.dart';
import '../application/filters_controller.dart';
import '../application/trip_controller.dart';
import '../domain/ride_models.dart';
import 'widgets/provider_badge.dart';
import 'widgets/route_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Current-location detection: fill the pickup automatically if the user has
    // already allowed location access. Otherwise wait for them to ask.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(tripProvider).pickup == null) {
        ref.read(tripProvider.notifier).useCurrentLocation(onlyIfPermitted: true);
      }
    });
  }

  void _compare() => context.push('/results');

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.lg, Gaps.page, Gaps.xxxl),
              sliver: SliverList.list(
                children: [
                  const FadeSlideIn(child: _BrandBar()),
                  const SizedBox(height: Gaps.xxxl),
                  FadeSlideIn(index: 1, child: Text('Where are you\ngoing today?', style: t.headlineMedium)),
                  const SizedBox(height: Gaps.sm),
                  FadeSlideIn(index: 2, child: Text('Compare Uber, Ola and Rapido in one place.', style: t.bodyMedium)),
                  const SizedBox(height: Gaps.xxl),
                  FadeSlideIn(index: 3, child: _TripCard(trip: trip)),
                  if (trip.locationError != null) ...[
                    const SizedBox(height: Gaps.sm),
                    _LocationError(message: trip.locationError!.message),
                  ],
                  const SizedBox(height: Gaps.lg),
                  FadeSlideIn(
                    index: 4,
                    child: FilledButton(
                      onPressed: trip.isComplete ? _compare : null,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Compare prices'),
                          SizedBox(width: Gaps.sm),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Gaps.xxxl),
                  FadeSlideIn(index: 5, child: Text('Ride type', style: t.titleMedium)),
                  const SizedBox(height: Gaps.md),
                  const FadeSlideIn(index: 6, child: _CategoryPicker()),
                  const SizedBox(height: Gaps.xxxl),
                  const FadeSlideIn(index: 7, child: _RecentSearches()),
                  const SizedBox(height: Gaps.xxl),
                  FadeSlideIn(
                    index: 8,
                    child: Text(
                      'RideCompare shows price estimates only. It does not book rides or connect to your provider accounts.',
                      style: t.bodySmall?.copyWith(color: AppColors.inkFaint),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  const _BrandBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: Gaps.sm + 2),
        Text('RideCompare', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17)),
        const Spacer(),
        for (final p in RideProvider.values)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ProviderDot(provider: p, size: 12),
          ),
      ],
    );
  }
}

/// Pickup + destination fields with a swap button.
class _TripCard extends ConsumerWidget {
  const _TripCard({required this.trip});
  final TripState trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSwap = trip.pickup != null || trip.drop != null;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              _TripField(field: TripField.pickup, place: trip.pickup, loading: trip.detectingLocation),
              const Padding(padding: EdgeInsets.only(left: 52, right: 64), child: Divider()),
              _TripField(field: TripField.drop, place: trip.drop),
            ],
          ),
          // Dotted connector between the two markers.
          Positioned(
            left: 25,
            top: 38,
            bottom: 38,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (_) => Container(width: 2, height: 3, color: AppColors.inkFaint)),
            ),
          ),
          Positioned(
            right: Gaps.md,
            top: 0,
            bottom: 0,
            child: Center(child: _SwapButton(onPressed: canSwap ? () => ref.read(tripProvider.notifier).swap() : null)),
          ),
        ],
      ),
    );
  }
}

class _TripField extends StatelessWidget {
  const _TripField({required this.field, required this.place, this.loading = false});
  final TripField field;
  final Place? place;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final empty = place == null;
    final String title;
    if (loading && empty) {
      title = 'Finding your location…';
    } else {
      title = place?.label ?? field.hint;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.lg),
      onTap: () => context.push('/search/${field.name}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.lg + 4, Gaps.lg, 64, Gaps.lg),
        child: Row(
          children: [
            StopMarker(isPickup: field == TripField.pickup),
            const SizedBox(width: Gaps.lg + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
                    child: Row(
                      key: ValueKey(title),
                      children: [
                        if (loading && empty) ...[
                          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: Gaps.sm),
                        ],
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleMedium?.copyWith(
                              color: empty ? AppColors.inkFaint : AppColors.ink,
                              fontWeight: empty ? FontWeight.w500 : FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwapButton extends StatefulWidget {
  const _SwapButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  State<_SwapButton> createState() => _SwapButtonState();
}

class _SwapButtonState extends State<_SwapButton> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Swap pickup and destination',
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onPressed == null
              ? null
              : () {
                  setState(() => _turns += 0.5);
                  widget.onPressed!();
                },
          child: SizedBox(
            width: 42,
            height: 42,
            child: AnimatedRotation(
              turns: _turns,
              duration: Motion.slow,
              curve: Motion.curve,
              child: Icon(
                Icons.swap_vert_rounded,
                color: widget.onPressed == null ? AppColors.inkFaint : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationError extends StatelessWidget {
  const _LocationError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.location_off_rounded, size: 16, color: AppColors.danger),
      const SizedBox(width: 6),
      Expanded(
        child: Text(message, style: const TextStyle(fontSize: 12.5, color: AppColors.danger)),
      ),
    ],
  );
}

/// Pre-selects which ride category the results open on.
class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(filtersProvider.select((f) => f.category));
    return Row(
      children: [
        for (final c in RideCategory.values) ...[
          Expanded(
            child: Pressable(
              semanticLabel: '${c.label} rides',
              onTap: () => ref.read(filtersProvider.notifier).setCategory(selected == c ? null : c),
              child: AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.curve,
                padding: const EdgeInsets.symmetric(vertical: Gaps.lg),
                decoration: BoxDecoration(
                  color: selected == c ? AppColors.ink : AppColors.surface,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: Column(
                  children: [
                    Icon(c.icon, size: 28, color: selected == c ? Colors.white : AppColors.ink),
                    const SizedBox(height: Gaps.sm),
                    Text(
                      c.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected == c ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (c != RideCategory.values.last) const SizedBox(width: Gaps.md),
        ],
      ],
    );
  }
}

/// Recent trips from the backend (MongoDB). Hidden if unavailable.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    final items = recent.value ?? const <RecentSearch>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent', style: t.titleMedium),
        const SizedBox(height: Gaps.sm),
        for (final s in items)
          InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: () {
              ref.read(tripProvider.notifier).setBoth(s.pickup, s.drop);
              context.push('/results');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gaps.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                    child: const Icon(Icons.history_rounded, size: 20),
                  ),
                  const SizedBox(width: Gaps.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.drop.name, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('from ${s.pickup.name}', style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (s.cheapestFare != null)
                    Text(
                      'from ${Fmt.money(s.cheapestFare!)}',
                      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
