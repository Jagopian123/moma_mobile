import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static String format(double amount) => _formatter.format(amount);

  static String formatCompact(double amount) {
    if (amount >= 1000000000) {
      return 'Rp${_strip(amount / 1000000000)}M';
    } else if (amount >= 1000000) {
      return 'Rp${_strip(amount / 1000000)}jt';
    } else if (amount >= 1000) {
      return 'Rp${_strip(amount / 1000)}rb';
    }
    return format(amount);
  }

  // 2 decimal places, trailing zeros stripped: 4.95 → "4.95", 5.0 → "5", 1.5 → "1.5"
  static String _strip(double v) =>
      v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
}
