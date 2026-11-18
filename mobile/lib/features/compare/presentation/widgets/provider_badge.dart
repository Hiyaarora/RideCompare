import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/ride_models.dart';

/// Neutral monogram badges. RideCompare does not use providers' logos or trademarks
/// as artwork, only their names, to identify whose estimate a row shows.
extension RideProviderStyle on RideProvider {
  Color get color => switch (this) {
    RideProvider.uber => const Color(0xFF111111),
    RideProvider.ola => const Color(0xFF2E9E5B),
    RideProvider.rapido => const Color(0xFFFFCC1F),
  };

  Color get onColor => this == RideProvider.rapido ? AppColors.ink : Colors.white;

  String get monogram => switch (this) {
    RideProvider.uber => 'U',
    RideProvider.ola => 'O',
    RideProvider.rapido => 'R',
  };
}

extension RideCategoryIcon on RideCategory {
  IconData get icon => switch (this) {
    RideCategory.bike => Icons.two_wheeler_rounded,
    RideCategory.auto => Icons.electric_rickshaw_rounded,
    RideCategory.car => Icons.directions_car_filled_rounded,
  };
}

class ProviderBadge extends StatelessWidget {
  const ProviderBadge({super.key, required this.provider, required this.category, this.size = 52});

  final RideProvider provider;
  final RideCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mini = size * 0.42;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(size * 0.3)),
            child: Icon(category.icon, size: size * 0.5, color: AppColors.ink),
          ),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: mini,
              height: mini,
              decoration: BoxDecoration(
                color: provider.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                provider.monogram,
                style: TextStyle(
                  color: provider.onColor,
                  fontSize: mini * 0.48,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small provider dot + name, used in filters and status rows.
class ProviderDot extends StatelessWidget {
  const ProviderDot({super.key, required this.provider, this.size = 10});
  final RideProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: provider.color,
      shape: BoxShape.circle,
      border: provider == RideProvider.rapido ? Border.all(color: const Color(0xFFE0B000), width: 1) : null,
    ),
  );
}
