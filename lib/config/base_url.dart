class ApiConfig {
  static const String _defaultBaseUrl =
      "https://fitbackend-production.up.railway.app";
  static const String _definedBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static String get baseUrl {
    final value = _definedBaseUrl.trim();
    if (value.isEmpty) {
      return _defaultBaseUrl;
    }
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
