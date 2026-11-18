import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _num = NumberFormat.decimalPattern('en_IN');

  static String money(num amount, {String currency = 'INR'}) => currency == 'INR'
      ? _inr.format(amount)
      : NumberFormat.simpleCurrency(name: currency, decimalDigits: 0).format(amount);

  /// "₹254" for a fixed fare, "₹260–285" for a range.
  static String fareRange(num min, num max, {String currency = 'INR'}) {
    if (min == max) return money(min, currency: currency);
    return '${money(min, currency: currency)}–${_num.format(max)}';
  }

  static String minutes(int? m) {
    if (m == null) return '—';
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '$h h' : '$h h $r min';
  }

  static String km(num? km) {
    if (km == null) return '—';
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  static String time(DateTime t) => DateFormat.jm().format(t.toLocal());
}
