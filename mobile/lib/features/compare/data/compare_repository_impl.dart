import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../places/domain/place.dart';
import '../domain/compare_repository.dart';
import '../domain/ride_models.dart';

class ApiCompareRepository implements CompareRepository {
  ApiCompareRepository(this._api);
  final ApiClient _api;

  @override
  Future<Comparison> compare({required Place pickup, required Place drop}) async {
    // All providers and categories are requested; filtering happens instantly on-device.
    final json = await _api.post('/compare', {'pickup': pickup.toJson(), 'drop': drop.toJson()});
    try {
      return Comparison.fromJson(json, pickup: pickup, drop: drop);
    } catch (_) {
      throw const UnexpectedFailure('We received prices in an unexpected format. Please try again.');
    }
  }

  @override
  Future<List<RecentSearch>> recentSearches({int limit = 5}) async {
    final json = await _api.get('/searches/recent', query: {'limit': limit});
    return (json['searches'] as List? ?? const [])
        .map((e) => RecentSearch.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
