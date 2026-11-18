// End-to-end flow against the REAL backend (start it first: cd backend && npm start).
// Run on a simulator/emulator:  flutter test integration_test -d <device-id>
// Pauses (PAUSE_MS) leave time for screenshots when recording a walkthrough.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ridecompare/app.dart';
import 'package:ridecompare/core/maps/app_maps.dart';
import 'package:ridecompare/features/compare/application/comparison_controller.dart';
import 'package:ridecompare/features/compare/domain/ride_models.dart';
import 'package:ridecompare/features/compare/presentation/results_screen.dart';
import 'package:ridecompare/features/compare/presentation/widgets/ride_option_card.dart';

const _pause = int.fromEnvironment('PAUSE_MS', defaultValue: 0);

Future<void> _wait(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $f');
}

Future<void> _settle(WidgetTester t, [int extraMs = 0]) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  if (extraMs > 0) await t.pump(Duration(milliseconds: extraMs));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search → compare → filter → details, against the live backend', (t) async {
    // The runner script grants location permission from outside (simctl / adb), since a test
    // can't tap the system dialog. Wait for it so the app starts like a returning user's would.
    for (var i = 0; i < 30; i++) {
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.whileInUse || p == LocationPermission.always) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await t.pumpWidget(ProviderScope(retry: (_, _) => null, child: const RideCompareApp()));
    await _settle(t, _pause);

    // Destination via autocomplete
    await t.tap(find.text('Where are you going?'));
    await _settle(t);
    await t.enterText(find.byType(TextField), 'south extension flyover');
    // Results depend on the live search service (Geoapify / OSM / offline list): take the first one.
    final suggestion = find.byIcon(Icons.place_outlined);
    await _wait(t, suggestion);
    await _settle(t, _pause);
    final chosen = t
        .widget<Text>(
          find
              .descendant(
                of: find.ancestor(of: suggestion.first, matching: find.byType(ListTile)),
                matching: find.byType(Text),
              )
              .first,
        )
        .data!;
    await t.tap(suggestion.first);
    await _wait(t, find.text('Compare prices'));
    await _settle(t);
    expect(find.text(chosen), findsWidgets, reason: 'chosen destination shown on home');

    // Pickup via current location (simulator location is set to central Bengaluru).
    // With permission already granted the app detects it on launch; otherwise do it explicitly.
    if (find.text('Current location').evaluate().isEmpty) {
      await t.tap(find.text('PICKUP'));
      await _settle(t);
      await t.tap(find.text('Use current location'));
      await _wait(t, find.text('Current location'));
    }
    await _settle(t, _pause);

    // Compare. Only real prices from authorised APIs are ever shown; with no provider credentials
    // configured the app must say "Live pricing unavailable" and show no prices at all.
    await t.tap(find.text('Compare prices'));
    await _wait(
      t,
      find.byType(RideOptionCard).evaluate().isNotEmpty
          ? find.byType(RideOptionCard)
          : find.text('Live pricing unavailable'),
    );
    await _settle(t, 600);
    final container = ProviderScope.containerOf(t.element(find.byType(ResultsScreen)));
    final comparison = container.read(comparisonProvider).requireValue;
    expect(find.textContaining('Demo'), findsNothing);

    if (comparison.dataMode == DataMode.unavailable) {
      expect(comparison.options, isEmpty);
      expect(find.text('Live pricing unavailable'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing, reason: 'no invented prices');
      for (final p in RideProvider.values) {
        expect(find.textContaining('${p.label}: Live pricing unavailable'), findsOneWidget);
      }
      await t.pump(Duration(milliseconds: _pause));
      await t.tap(find.byTooltip('Refresh prices'));
      await _wait(t, find.text('Live pricing unavailable'));
      return;
    }

    // Live prices: cheapest first, filter, details.
    expect(comparison.options.every((o) => o.provider != RideProvider.rapido), isTrue, reason: 'Rapido has no API');
    expect(find.text(comparison.options.first.productName), findsOneWidget, reason: 'top card is the cheapest');
    final first = comparison.options.first;
    await t.tap(find.byType(RideOptionCard).first);
    await _wait(t, find.text('Ride details'));
    await _settle(t, 600);
    expect(find.text(first.isUpfront ? 'Upfront fare' : 'Estimated fare'), findsOneWidget);
    expect(find.text(first.isUpfront ? 'LIVE · UPFRONT FARE' : 'LIVE · ESTIMATE'), findsOneWidget);
    await t.pageBack();
    await _settle(t);
  });

  testWidgets('choose destination on the free OpenStreetMap map', (t) async {
    await t.pumpWidget(ProviderScope(retry: (_, _) => null, child: const RideCompareApp()));
    await _settle(t);
    await t.tap(find.text('DESTINATION'));
    await _settle(t);
    await t.tap(find.text('Choose on map'));
    await _wait(t, find.text('Drag the map to move the pin'));
    // Let tiles load and the pin's address resolve.
    await _wait(t, find.widgetWithText(FilledButton, 'Confirm destination'));
    final confirm = find.widgetWithText(FilledButton, 'Confirm destination');
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (t.widget<FilledButton>(confirm).onPressed == null && DateTime.now().isBefore(end)) {
      await t.pump(const Duration(milliseconds: 200));
    }
    await _settle(t, _pause + 1500);
    // Drag the map; the pin's address updates.
    await t.drag(find.byType(PickerMap), const Offset(-120, 160));
    await _settle(t, 1500);
    while (t.widget<FilledButton>(confirm).onPressed == null &&
        DateTime.now().isBefore(end.add(const Duration(seconds: 20)))) {
      await t.pump(const Duration(milliseconds: 200));
    }
    await _settle(t, _pause);
    await t.tap(confirm);
    await _wait(t, find.text('Compare prices'));
    await _settle(t, _pause);
    expect(find.text('Where are you going?'), findsNothing, reason: 'destination was set from the map');
  });
}
