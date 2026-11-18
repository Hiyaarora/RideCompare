import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridecompare/core/error/app_failure.dart';
import 'package:ridecompare/core/network/api_client.dart';
import 'package:ridecompare/core/utils/formatters.dart';
import 'package:ridecompare/features/compare/application/filters_controller.dart';
import 'package:ridecompare/features/compare/domain/ride_models.dart';
import 'package:ridecompare/features/places/domain/place.dart';

import 'fixtures.dart';

void main() {
  const pickup = Place(name: 'MG Road', lat: 12.9755, lng: 77.6068);
  const drop = Place(name: 'HSR Layout', lat: 12.9121, lng: 77.6446);

  group('Comparison.fromJson', () {
    final c = Comparison.fromJson(sampleComparisonJson(), pickup: pickup, drop: drop);

    test('parses options, providers and route', () {
      expect(c.options, hasLength(4));
      expect(c.dataMode, DataMode.live);
      expect(c.route.distanceKm, 11);
      expect(c.route.isEstimated, isTrue);
      expect(c.providers.map((p) => p.provider), [RideProvider.uber, RideProvider.ola, RideProvider.rapido]);
      final rapido = c.providers.firstWhere((p) => p.provider == RideProvider.rapido);
      expect(rapido.state, ProviderState.unavailable);
      expect(rapido.live, isFalse);
      expect(rapido.reason, contains('no official'));
      final olaBike = c.optionById('ola:bike')!;
      expect(olaBike.priceType, PriceType.upfront);
      expect(olaBike.fare.upfront, 83);
      expect(olaBike.category, RideCategory.bike);
      final moto = c.optionById('uber:moto')!;
      expect(moto.priceType, PriceType.estimate);
      expect(moto.fare.upfront, isNull);
      expect(moto.fetchedAt.toUtc().hour, 7);
    });

    test('parses the "live pricing unavailable" response', () {
      final u = Comparison.fromJson(unavailableComparisonJson(), pickup: pickup, drop: drop);
      expect(u.dataMode, DataMode.unavailable);
      expect(u.options, isEmpty);
      expect(u.providers.every((p) => p.state == ProviderState.unavailable), isTrue);
    });

    test('ignores options from unknown providers instead of crashing', () {
      final json = sampleComparisonJson();
      (json['options'] as List).add({
        ...(json['options'] as List).first as Map<String, dynamic>,
        'id': 'x:y',
        'provider': 'lyft',
      });
      final parsed = Comparison.fromJson(json, pickup: pickup, drop: drop);
      expect(parsed.options.where((o) => o.id == 'x:y'), isEmpty);
    });
  });

  group('applyFilters', () {
    final options = Comparison.fromJson(sampleComparisonJson(), pickup: pickup, drop: drop).options;

    test('default shows everything cheapest first', () {
      final r = applyFilters(options, const FiltersState());
      expect(r.map((o) => o.fare.min), [83, 95, 195, 295]);
    });

    test('filters by category and provider', () {
      final bikes = applyFilters(options, const FiltersState(category: RideCategory.bike));
      expect(bikes.every((o) => o.category == RideCategory.bike), isTrue);
      final onlyUber = applyFilters(options, const FiltersState(providers: {RideProvider.uber}));
      expect(onlyUber.map((o) => o.provider).toSet(), {RideProvider.uber});
      expect(applyFilters(options, const FiltersState(providers: {})), isEmpty);
    });

    test('fastest sorts by pickup ETA + trip time', () {
      final r = applyFilters(options, const FiltersState(sort: SortMode.fastest));
      for (var i = 1; i < r.length; i++) {
        expect(r[i - 1].totalMinutes <= r[i].totalMinutes, isTrue);
      }
    });

    test('category counts respect the provider filter', () {
      final counts = categoryCounts(options, {RideProvider.ola});
      expect(counts[null], 2);
      expect(counts[RideCategory.bike], 1);
      expect(counts[RideCategory.car], 0);
    });
  });

  group('error mapping', () {
    RequestOptions ro() => RequestOptions(path: '/compare');

    test('connection errors become NetworkFailure', () {
      expect(
        mapDioException(DioException(requestOptions: ro(), type: DioExceptionType.connectionError)),
        isA<NetworkFailure>(),
      );
    });

    test('timeouts become TimeoutFailure', () {
      expect(
        mapDioException(DioException(requestOptions: ro(), type: DioExceptionType.receiveTimeout)),
        isA<TimeoutFailure>(),
      );
    });

    test('API errors keep the server message and reason', () {
      final f = mapDioException(
        DioException(
          requestOptions: ro(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: ro(),
            statusCode: 400,
            data: {
              'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Pickup and destination are the same place',
                'details': {'reason': 'SAME_LOCATION'},
              },
            },
          ),
        ),
      );
      expect(f, isA<ServerFailure>());
      f as ServerFailure;
      expect(f.message, contains('same place'));
      expect(f.reason, 'SAME_LOCATION');
      expect(f.canRetry, isFalse);
    });
  });

  group('formatters', () {
    test('fares use rupees with Indian grouping', () {
      expect(Fmt.fareRange(260, 285), '₹260–285');
      expect(Fmt.fareRange(254, 254), '₹254');
      expect(Fmt.money(125000), '₹1,25,000');
    });

    test('durations and distances', () {
      expect(Fmt.minutes(45), '45 min');
      expect(Fmt.minutes(60), '1 h');
      expect(Fmt.minutes(95), '1 h 35 min');
      expect(Fmt.km(4.26), '4.3 km');
      expect(Fmt.km(37.6), '38 km');
    });
  });
}
