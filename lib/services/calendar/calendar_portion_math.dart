/// Positive decimal inputs with up to three places, matching the API bounds.
class CalendarPortionMath {
  static int? units(String value) {
    if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(value.trim())) return null;
    final parts = value.trim().split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null || whole > 1000) return null;
    return whole * 1000 +
        int.parse(parts.length == 1 ? '000' : parts[1].padRight(3, '0'));
  }

  static int rounded(num value, int numerator, int denominator) {
    final product = BigInt.from(value.toInt()) * BigInt.from(numerator);
    final divisor = BigInt.from(denominator);
    return ((product * BigInt.two + divisor) ~/ (divisor * BigInt.two)).toInt();
  }

  static const macros = ['calories', 'protein_g', 'carbs_g', 'fat_g'];
  static Map<String, int> totals(
    List<Map<String, dynamic>> items,
    int numerator,
    int denominator,
  ) => {
    for (final key in macros)
      key: items.fold<int>(
        0,
        (sum, item) =>
            sum + rounded((item[key] as num?) ?? 0, numerator, denominator),
      ),
  };
}
