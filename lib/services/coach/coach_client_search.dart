String _normalizeSearchText(String value) => value.trim().toLowerCase();

String _compactSearchText(String value) =>
    _normalizeSearchText(value).replaceAll(RegExp(r'[\s@._+\-]+'), '');

/// Matches every query term against any known client identity field.
///
/// Terms may be entered in any order, and common username/email separators
/// are ignored as a fallback. This makes searches such as `doe john`,
/// `@john_doe`, and `john gmail` behave naturally.
bool matchesCoachClientSearch({
  required String query,
  required Iterable<String?> fields,
}) {
  final normalizedQuery = _normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return true;

  final normalizedFields = fields
      .map((value) => _normalizeSearchText(value ?? ''))
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  if (normalizedFields.isEmpty) return false;

  final combined = normalizedFields.join(' ');
  final compactCombined = _compactSearchText(combined);
  final terms = normalizedQuery
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty);

  return terms.every((term) {
    if (combined.contains(term)) return true;
    final compactTerm = _compactSearchText(term);
    return compactTerm.isNotEmpty && compactCombined.contains(compactTerm);
  });
}
