import 'package:material_ui/material_ui.dart';

/// Design tokens. Every colour, gap and radius in the app comes from here.
abstract final class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF6F7F9);
  static const surfaceStrong = Color(0xFFEEF0F3);
  static const border = Color(0xFFE7E9EE);
  static const ink = Color(0xFF0E0F12);
  static const inkMuted = Color(0xFF5B606B);
  static const inkFaint = Color(0xFF9198A4);

  static const accent = Color(0xFF0E0F12);
  static const success = Color(0xFF13A15A);
  static const successSoft = Color(0xFFE5F6EC);
  static const info = Color(0xFF2563EB);
  static const infoSoft = Color(0xFFE6EEFD);
  static const warning = Color(0xFFB45309);
  static const warningSoft = Color(0xFFFFF3DC);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFDECEC);

  static const pickupDot = Color(0xFF13A15A);
}

abstract final class Gaps {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const page = 20.0;
}

abstract final class Radii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
}
