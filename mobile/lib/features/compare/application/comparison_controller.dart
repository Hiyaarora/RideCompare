import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../data/compare_repository_impl.dart';
import '../domain/compare_repository.dart';
import '../domain/ride_models.dart';
import 'trip_controller.dart';

final compareRepositoryProvider = Provider<CompareRepository>(
  (ref) => ApiCompareRepository(ref.watch(apiClientProvider)),
);

/// Fetches the comparison for the current trip. Re-runs automatically when the
/// trip changes and is disposed when no screen is showing results.
class ComparisonController extends AsyncNotifier<Comparison> {
  @override
  Future<Comparison> build() async {
    final (pickup, drop) = ref.watch(tripProvider.select((t) => (t.pickup, t.drop)));
    if (pickup == null || drop == null) {
      throw const ServerFailure('Choose a pickup and a destination first.', code: 'VALIDATION_ERROR');
    }
    return ref.watch(compareRepositoryProvider).compare(pickup: pickup, drop: drop);
  }

  /// Re-fetches prices while keeping the current results on screen.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The error is in `state`; the screen decides how to show it.
    }
  }
}

final comparisonProvider = AsyncNotifierProvider.autoDispose<ComparisonController, Comparison>(
  ComparisonController.new,
);

final recentSearchesProvider = FutureProvider.autoDispose<List<RecentSearch>>((ref) {
  return ref.watch(compareRepositoryProvider).recentSearches(limit: 4);
});
