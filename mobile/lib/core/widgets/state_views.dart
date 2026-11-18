import 'package:material_ui/material_ui.dart';

import '../error/app_failure.dart';
import '../theme/tokens.dart';

/// Centered message with an icon, used for empty and error states.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
    this.iconColor = AppColors.ink,
    this.iconBackground = AppColors.surface,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.xxxl, vertical: Gaps.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: iconColor),
          ),
          const SizedBox(height: Gaps.xl),
          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: Gaps.sm),
          Text(message, style: t.bodyMedium, textAlign: TextAlign.center),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: Gaps.xxl),
            Wrap(spacing: Gaps.md, runSpacing: Gaps.md, alignment: WrapAlignment.center, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Error state for an [AppFailure], with a retry button when retrying can help.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.extraActions = const []});

  final Object error;
  final VoidCallback? onRetry;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    final f = toFailure(error);
    final icon = switch (f) {
      NetworkFailure() => Icons.wifi_off_rounded,
      TimeoutFailure() => Icons.hourglass_bottom_rounded,
      LocationFailure() => Icons.location_off_rounded,
      ServerFailure(code: 'VALIDATION_ERROR') => Icons.edit_location_alt_rounded,
      _ => Icons.error_outline_rounded,
    };
    return MessageView(
      icon: icon,
      iconColor: AppColors.danger,
      iconBackground: AppColors.dangerSoft,
      title: f.title,
      message: f.message,
      actions: [
        if (onRetry != null && f.canRetry)
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Try again'),
          ),
        ...extraActions,
      ],
    );
  }
}

/// A gently pulsing placeholder block for loading skeletons.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = Radii.sm});
  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: AppColors.surfaceStrong, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}
