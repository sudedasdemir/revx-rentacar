import 'package:intl/intl.dart';

class PriceFormatter {
  static final _currencyFormat = NumberFormat.currency(
    symbol: '₺',
    decimalDigits: 2,
  );
  static final _percentFormat = NumberFormat.decimalPercentPattern(
    decimalDigits: 1,
  );

  static String formatPrice(double price, {double? discountPercentage}) {
    if (discountPercentage != null && discountPercentage > 0) {
      final discountedPrice = price * (100 - discountPercentage) / 100;
      return _currencyFormat.format(discountedPrice);
    }
    return _currencyFormat.format(price);
  }

  static String formatDiscount(double discountPercentage) {
    return _percentFormat.format(discountPercentage / 100);
  }

  static String formatPriceWithDiscount(
    double price,
    double? discountPercentage,
  ) {
    if (discountPercentage != null && discountPercentage > 0) {
      final discountedPrice = price * (100 - discountPercentage) / 100;
      return '${_currencyFormat.format(discountedPrice)} (${_percentFormat.format(discountPercentage / 100)} off)';
    }
    return _currencyFormat.format(price);
  }
}
