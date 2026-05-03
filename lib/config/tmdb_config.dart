class TmdbConfig {
  static const String _originalProxy = 'https://tmdb.nanfang534.workers.dev';
  static const String _customProxy = 'https://yule.qzz.io/';

  static const String proxyBase =
      String.fromEnvironment('TMDB_PROXY_BASE',
          defaultValue: _customProxy);
  static const String readToken =
      String.fromEnvironment('TMDB_READ_TOKEN', defaultValue: '');
  static const String apiKey =
      String.fromEnvironment('TMDB_API_KEY', defaultValue: '');
}
