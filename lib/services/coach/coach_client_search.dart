String _normalizeSearchText(String value) => value.trim().toLowerCase();

String _compactSearchText(String value) =>
    _normalizeSearchText(value).replaceAll(RegExp(r'[\s@._+\-]+'), '');

/// Matches a coach's client search without treating common email domains as
/// client identity. Plain text searches names, usernames, and the local part
/// of an email address. Full/partial email matching is enabled only when the
/// query itself contains an `@`, and numeric user IDs must match exactly.
bool matchesCoachClientSearch({
  required String query,
  required Iterable<String?> identityFields,
  String? email,
  String? userId,
}) {
  final normalizedQuery = _normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return true;

  if (RegExp(r'^\d+$').hasMatch(normalizedQuery)) {
    return normalizedQuery == _normalizeSearchText(userId ?? '');
  }

  final normalizedEmail = _normalizeSearchText(email ?? '');
  final atIndex = normalizedQuery.indexOf('@');
  final looksLikeEmail = atIndex > 0;
  if (looksLikeEmail) {
    if (normalizedEmail.isEmpty) return false;
    return normalizedEmail.contains(normalizedQuery) ||
        _compactSearchText(
          normalizedEmail,
        ).contains(_compactSearchText(normalizedQuery));
  }

  final emailLocalPart = normalizedEmail.split('@').first;
  final normalizedFields =
      <String?>[
            ...identityFields,
            if (emailLocalPart.isNotEmpty) emailLocalPart,
          ]
          .map((value) => _normalizeSearchText(value ?? ''))
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
  if (normalizedFields.isEmpty) return false;

  final combined = normalizedFields.join(' ');
  final compactCombined = _compactSearchText(combined);
  final terms = normalizedQuery
      .replaceFirst(RegExp(r'^@+'), '')
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty);

  return terms.every((term) {
    if (combined.contains(term)) return true;
    final compactTerm = _compactSearchText(term);
    return compactTerm.isNotEmpty && compactCombined.contains(compactTerm);
  });
}
