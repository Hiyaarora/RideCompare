import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ride_models.dart';

enum SortMode {
  cheapest('Cheapest'),
  fastest('Fastest');

  const SortMode(this.label);
  final String label;
}

class FiltersState {
  const FiltersState({this.category, this.providers = const {...RideProvider.values}, this.sort = SortMode.cheapest});

  /// null = all categories.
  final RideCategory? category;
  final Set<RideProvider> providers;
  final SortMode sort;

  bool get isDefault => category == null && providers.length == RideProvider.values.length && sort == SortMode.cheapest;

  FiltersState copyWith({RideCategory? Function()? category, Set<RideProvider>? providers, SortMode? sort}) =>
      FiltersState(
        category: category != null ? category() : this.category,
        providers: providers ?? this.providers,
        sort: sort ?? this.sort,
      );
}

class FiltersController extends Notifier<FiltersState> {
  @override
  FiltersState build() => const FiltersState();

  void setCategory(RideCategory? c) => state = state.copyWith(category: () => c);

  void toggleProvider(RideProvider p) {
    final next = {...state.providers};
    if (!next.remove(p)) next.add(p);
    state = state.copyWith(providers: next);
  }

  void setSort(SortMode s) => state = state.copyWith(sort: s);

  void reset() => state = const FiltersState();
}

final filtersProvider = NotifierProvider<FiltersController, FiltersState>(FiltersController.new);

/// Applies the filters and sort to a comparison's options. Pure, so it's easy to test.
List<RideOption> applyFilters(List<RideOption> options, FiltersState f) {
  final list = options
      .where((o) => f.providers.contains(o.provider) && (f.category == null || o.category == f.category))
      .toList();
  switch (f.sort) {
    case SortMode.cheapest:
      list.sort((a, b) {
        final byMin = a.fare.min.compareTo(b.fare.min);
        return byMin != 0 ? byMin : a.totalMinutes.compareTo(b.totalMinutes);
      });
    case SortMode.fastest:
      list.sort((a, b) {
        final byTime = a.totalMinutes.compareTo(b.totalMinutes);
        return byTime != 0 ? byTime : a.fare.min.compareTo(b.fare.min);
      });
  }
  return list;
}

/// Number of options per category with the current provider filter, for the category tabs.
Map<RideCategory?, int> categoryCounts(List<RideOption> options, Set<RideProvider> providers) {
  final visible = options.where((o) => providers.contains(o.provider));
  return {null: visible.length, for (final c in RideCategory.values) c: visible.where((o) => o.category == c).length};
}
