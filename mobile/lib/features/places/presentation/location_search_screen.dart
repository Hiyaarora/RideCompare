import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../compare/application/trip_controller.dart';
import '../application/places_providers.dart';
import '../domain/place.dart';

/// Search for a pickup or destination: autocomplete, current location, or map.
class LocationSearchScreen extends ConsumerStatefulWidget {
  const LocationSearchScreen({super.key, required this.field});
  final TripField field;

  @override
  ConsumerState<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends ConsumerState<LocationSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  // One session token per search, as Google recommends for Places billing.
  final _sessionToken = const Uuid().v4();
  Timer? _debounce;
  String _query = '';
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _query = _controller.text.trim());
      });
      setState(() {}); // refresh clear button
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Bias results towards the other trip end, so "airport" finds the nearby one.
  ({double lat, double lng})? get _bias {
    final trip = ref.read(tripProvider);
    final other = widget.field == TripField.pickup ? trip.drop : trip.pickup;
    final p = other ?? trip[widget.field];
    return p == null ? null : (lat: p.lat, lng: p.lng);
  }

  Future<void> _choose(Future<Place> Function() resolve) async {
    if (_resolving) return;
    setState(() => _resolving = true);
    try {
      final place = await resolve();
      if (!mounted) return;
      ref.read(tripProvider.notifier).set(widget.field, place);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final f = toFailure(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(f.message),
          action: f is LocationFailure && f.openSettings
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => ref.read(locationServiceProvider).openSettings(),
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _openMap() async {
    final current = ref.read(tripProvider)[widget.field];
    final place = await context.push<Place>('/map/${widget.field.name}', extra: current);
    if (place != null && mounted) {
      ref.read(tripProvider.notifier).set(widget.field, place);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final bias = _bias;
    final searching = _query.length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.field == TripField.pickup ? 'Set pickup' : 'Set destination'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _resolving ? const LinearProgressIndicator(minHeight: 2) : const SizedBox(height: 2),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.md),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.field.hint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: _controller.clear),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (widget.field == TripField.pickup)
                  _ActionTile(
                    icon: Icons.my_location_rounded,
                    title: 'Use current location',
                    subtitle: 'Detect where you are now',
                    onTap: () => _choose(ref.read(currentPlaceLoader)),
                  ),
                _ActionTile(
                  icon: Icons.map_outlined,
                  title: 'Choose on map',
                  subtitle: 'Drop a pin at the exact spot',
                  onTap: _openMap,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Gaps.page),
                  child: Divider(),
                ),
                if (!searching)
                  Padding(
                    padding: const EdgeInsets.all(Gaps.page),
                    child: Text('Search for a landmark, area or address.', style: t.bodyMedium),
                  )
                else
                  _Suggestions(
                    args: (query: _query, sessionToken: _sessionToken, lat: bias?.lat, lng: bias?.lng),
                    onPickOnMap: _openMap,
                    onSelected: (s) => _choose(
                      () => ref.read(placesRepositoryProvider).details(s.placeId, sessionToken: _sessionToken),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.args, required this.onSelected, required this.onPickOnMap});
  final AutocompleteArgs args;
  final ValueChanged<PlaceSuggestion> onSelected;
  final VoidCallback onPickOnMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(autocompleteProvider(args));
    final t = Theme.of(context).textTheme;

    return AnimatedSwitcher(
      duration: Motion.fast,
      child: async.when(
        skipLoadingOnReload: true,
        loading: () => Padding(
          key: const ValueKey('loading'),
          padding: const EdgeInsets.all(Gaps.page),
          child: Column(
            children: [
              for (var i = 0; i < 4; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: Gaps.lg),
                  child: Row(
                    children: [
                      SkeletonBox(width: 36, height: 36, radius: 18),
                      SizedBox(width: Gaps.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 160, height: 14),
                            SizedBox(height: 6),
                            SkeletonBox(width: 220, height: 11),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        error: (e, _) => ErrorView(
          key: const ValueKey('error'),
          error: e,
          onRetry: () => ref.invalidate(autocompleteProvider(args)),
        ),
        data: (result) => result.suggestions.isEmpty
            ? MessageView(
                key: const ValueKey('empty'),
                icon: Icons.travel_explore_rounded,
                title: 'No places found',
                message:
                    'Nothing matches “${args.query}”. Check the spelling, try a nearby landmark or area, or drop a pin on the map.',
                actions: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
                    onPressed: onPickOnMap,
                    icon: const Icon(Icons.map_outlined, size: 20),
                    label: const Text('Choose on map'),
                  ),
                ],
              )
            : Column(
                key: ValueKey('data-${args.query}'),
                children: [
                  for (final s in result.suggestions)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: Gaps.page, vertical: 2),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                        child: const Icon(Icons.place_outlined, size: 20),
                      ),
                      title: Text(s.primaryText, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(s.secondaryText, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: s.distanceKm == null ? null : Text(Fmt.km(s.distanceKm), style: t.bodySmall),
                      onTap: () => onSelected(s),
                    ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: Gaps.page, vertical: 2),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                      child: const Icon(Icons.edit_location_alt_outlined, size: 20),
                    ),
                    title: Text("Can't find your place?", style: t.titleSmall),
                    subtitle: Text('Drop a pin on the map instead', style: t.bodySmall),
                    onTap: onPickOnMap,
                  ),
                  _SearchAttribution(source: result.source),
                ],
              ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: Gaps.page, vertical: 2),
    leading: Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: Colors.white),
    ),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    onTap: onTap,
  );
}

/// Credits required by the free search services' terms.
class _SearchAttribution extends StatelessWidget {
  const _SearchAttribution({required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final text = switch (source) {
      'geoapify' => 'Powered by Geoapify · © OpenStreetMap contributors',
      'osm' => 'Search by Photon · © OpenStreetMap contributors',
      'google' => 'Powered by Google',
      _ => 'Showing popular places (offline list)',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, Gaps.xl),
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
    );
  }
}
