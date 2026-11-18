import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/tokens.dart';
import '../../application/filters_controller.dart';
import '../../domain/ride_models.dart';
import 'provider_badge.dart';

/// Category tabs + provider toggles + sort. Pinned above the results list.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key, required this.options, required this.providerStates});

  final List<RideOption> options;
  final Map<RideProvider, ProviderState> providerStates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtersProvider);
    final ctrl = ref.read(filtersProvider.notifier);
    final counts = categoryCounts(options, f.providers);

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category segmented control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(
              children: [
                for (final c in <RideCategory?>[null, ...RideCategory.values])
                  Expanded(
                    child: _Segment(
                      label: c?.label ?? 'All',
                      icon: c?.icon,
                      count: counts[c] ?? 0,
                      selected: f.category == c,
                      onTap: () => ctrl.setCategory(c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Gaps.md),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final p in RideProvider.values) ...[
                        _ProviderChip(
                          provider: p,
                          selected: f.providers.contains(p),
                          hasError: providerStates[p] == ProviderState.error,
                          onTap: () => ctrl.toggleProvider(p),
                        ),
                        const SizedBox(width: Gaps.sm),
                      ],
                    ],
                  ),
                ),
              ),
              _SortButton(sort: f.sort, onChanged: ctrl.setSort),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.count, required this.selected, required this.onTap, this.icon});
  final String label;
  final IconData? icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.ink : AppColors.inkMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: '$label, $count options',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? AppColors.background : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.sm),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 4)],
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: fg),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.inkMuted : AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.provider, required this.selected, required this.hasError, required this.onTap});
  final RideProvider provider;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: selected,
      label: '${provider.label} filter',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.background,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: selected ? AppColors.ink : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: Motion.fast,
                child: selected
                    ? const Icon(Icons.check_rounded, key: ValueKey('on'), size: 14, color: Colors.white)
                    : ProviderDot(key: const ValueKey('off'), provider: provider),
              ),
              const SizedBox(width: 6),
              Text(
                provider.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
              if (hasError) ...[
                const SizedBox(width: 4),
                Icon(Icons.error_rounded, size: 14, color: selected ? const Color(0xFFFCA5A5) : AppColors.danger),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});
  final SortMode sort;
  final ValueChanged<SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortMode>(
      tooltip: 'Sort',
      initialValue: sort,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      itemBuilder: (_) => [
        for (final s in SortMode.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(s == SortMode.cheapest ? Icons.savings_outlined : Icons.bolt_rounded, size: 18),
                const SizedBox(width: Gaps.sm),
                Text(s == SortMode.cheapest ? 'Cheapest first' : 'Fastest arrival first'),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert_rounded, size: 16),
            const SizedBox(width: 4),
            Text(sort.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
