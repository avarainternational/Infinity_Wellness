/// Exact nonnegative Stellar amounts in seven-decimal integer units.
final class RewardsAmount {
  static final BigInt maximum = BigInt.parse('9223372036854775807');
  static final BigInt scale = BigInt.from(10000000);

  static BigInt parse(Object? value) {
    if (value is! String ||
        value.length > 30 ||
        !RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]{1,7})?$').hasMatch(value)) {
      throw const FormatException('Invalid amount.');
    }
    final List<String> parts = value.split('.');
    final BigInt units =
        BigInt.parse(parts[0]) * scale +
        BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(7, '0'));
    if (units > maximum) throw const FormatException('Amount overflow.');
    return units;
  }

  static String display(BigInt units) {
    final String fraction = (units % scale)
        .toString()
        .padLeft(7, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty
        ? '${units ~/ scale}'
        : '${units ~/ scale}.$fraction';
  }
}
