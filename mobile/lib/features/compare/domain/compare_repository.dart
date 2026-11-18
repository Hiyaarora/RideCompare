import '../../places/domain/place.dart';
import 'ride_models.dart';

abstract interface class CompareRepository {
  Future<Comparison> compare({required Place pickup, required Place drop});
  Future<List<RecentSearch>> recentSearches({int limit = 5});
}
