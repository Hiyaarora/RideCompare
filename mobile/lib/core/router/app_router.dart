import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/compare/application/trip_controller.dart';
import '../../features/compare/presentation/home_screen.dart';
import '../../features/compare/presentation/results_screen.dart';
import '../../features/compare/presentation/ride_details_screen.dart';
import '../../features/places/domain/place.dart';
import '../../features/places/presentation/location_search_screen.dart';
import '../../features/places/presentation/map_picker_screen.dart';

TripField _field(GoRouterState s) =>
    TripField.values.firstWhere((f) => f.name == s.pathParameters['field'], orElse: () => TripField.drop);

/// Slide-up page used for modal-style flows (search, map).
CustomTransitionPage<T> _sheetPage<T>(GoRouterState state, Widget child) => CustomTransitionPage<T>(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 320),
  reverseTransitionDuration: const Duration(milliseconds: 240),
  transitionsBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  },
);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/search/:field',
        pageBuilder: (_, s) => _sheetPage(s, LocationSearchScreen(field: _field(s))),
      ),
      GoRoute(
        path: '/map/:field',
        pageBuilder: (_, s) => _sheetPage<Place>(s, MapPickerScreen(field: _field(s), initial: s.extra as Place?)),
      ),
      GoRoute(
        path: '/results',
        builder: (_, _) => const ResultsScreen(),
        routes: [
          GoRoute(
            path: 'option/:id',
            builder: (_, s) => RideDetailsScreen(optionId: s.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});
