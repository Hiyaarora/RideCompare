import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Small rounded label, e.g. "Cheapest", "Demo", "1.2× surge".
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.inkMuted,
    this.background = AppColors.surface,
  });

  const Pill.success({super.key, required this.label, this.icon})
    : color = AppColors.success,
      background = AppColors.successSoft;

  const Pill.info({super.key, required this.label, this.icon})
    : color = AppColors.info,
      background = AppColors.infoSoft;

  const Pill.warning({super.key, required this.label, this.icon})
    : color = AppColors.warning,
      background = AppColors.warningSoft;

  final String label;
  final IconData? icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
