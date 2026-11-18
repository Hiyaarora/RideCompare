import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ridecompare/core/error/app_failure.dart';
import 'package:ridecompare/core/theme/app_theme.dart';
import 'package:ridecompare/features/compare/application/comparison_controller.dart';
import 'package:ridecompare/features/compare/application/trip_controller.dart';
import 'package:ridecompare/features/compare/domain/compare_repository.dart';
import 'package:ridecompare/features/compare/domain/ride_models.dart';
import 'package:ridecompare/features/compare/presentation/results_screen.dart';
import 'package:ridecompare/features/places/domain/place.dart';

import 'fixtures.dart';

class _FakeRepo implements CompareRepository {
  _FakeRepo({this.fail, this.json = sampleComparisonJson});
  final AppFailure? fail;
  final Map<String, dynamic> Function() json;

  @override
  Future<Comparison> compare({required Place pickup, required Place drop}) async {
    if (fail != null) throw fail!;
    return Comparison.fromJson(json(), pickup: pickup, drop: drop);
  }

  @override
  Future<List<RecentSearch>> recentSearches({int limit = 5}) async => const [];
}

class _PresetTrip extends TripController {
  @override
  TripState build() => const TripState(
    pickup: Place(name: 'MG Road', lat: 12.9755, lng: 77.6068),
    drop: Place(name: 'HSR Layout', lat: 12.9121, lng: 77.6446),
  );
}

Widget _app(CompareRepository repo) => ProviderScope(
  retry: (_, _) => null,
  overrides: [compareRepositoryProvider.overrideWithValue(repo), tripProvider.overrideWith(_PresetTrip.new)],
  child: MaterialApp(theme: AppTheme.light(), home: const ResultsScreen()),
);

void main() {
  testWidgets('shows live options, price types, badges and the unavailable-provider note', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 2400));
    await tester.pumpWidget(_app(_FakeRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Ola Bike'), findsOneWidget);
    expect(find.text('Uber Go'), findsOneWidget);
    expect(find.text('₹83'), findsOneWidget);
    expect(find.text('₹295–325'), findsOneWidget);
    // The cheapest badge sits on the Ola Bike card (the sort button also says "Cheapest").
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('Ola Bike'), matching: find.byType(Row)).first,
        matching: find.text('Cheapest'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Demo'), findsNothing);
    expect(find.text('upfront fare'), findsWidgets);
    expect(find.text('live estimate'), findsWidgets);
    expect(find.textContaining('Rapido: Live pricing unavailable'), findsOneWidget);
    expect(find.textContaining('no official fare API'), findsOneWidget);
  });

  testWidgets('shows "Live pricing unavailable" and no prices when no provider is authorised', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 2400));
    await tester.pumpWidget(_app(_FakeRepo(json: unavailableComparisonJson)));
    await tester.pumpAndSettle();
    expect(find.text('Live pricing unavailable'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
    expect(find.textContaining('Uber: Live pricing unavailable'), findsOneWidget);
    expect(find.textContaining('Ola: Live pricing unavailable'), findsOneWidget);
    expect(find.textContaining('Rapido: Live pricing unavailable'), findsOneWidget);
  });

  testWidgets('category filter narrows the list and empty state offers reset', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 2400));
    await tester.pumpWidget(_app(_FakeRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Car'));
    await tester.pumpAndSettle();
    expect(find.text('Uber Go'), findsOneWidget);
    expect(find.text('Ola Bike'), findsNothing);

    // Turn off Uber: no cars left.
    await tester.tap(find.text('Uber').first);
    await tester.pumpAndSettle();
    expect(find.text('No rides match your filters'), findsOneWidget);
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(find.text('Ola Bike'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when the backend is unreachable', (tester) async {
    await tester.pumpWidget(_app(_FakeRepo(fail: const NetworkFailure())));
    await tester.pumpAndSettle();
    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
